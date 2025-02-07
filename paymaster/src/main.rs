use std::{collections::BTreeMap, sync::Arc};

use alloy::{
    network::{Ethereum, EthereumWallet},
    primitives::{Address, Bytes, FixedBytes, PrimitiveSignature, U256},
    providers::{Provider, ProviderBuilder},
    signers::{local::PrivateKeySigner, Signer},
    sol,
    transports::Transport,
};
use axum::{
    extract::Json,
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post},
    Router,
};
use eyre::{eyre, Result, WrapErr};
use serde::{Deserialize, Serialize};
use serde_json::json;
use tracing_subscriber;
use ClaimBatchProcessor::ClaimBatchProcessorInstance;

/// Request payload for batch claiming rewards
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
struct BatchClaimRequest {
    token_ids: BTreeMap<String, Vec<String>>,
    amount: String,
    proof: Vec<String>,
    signature: String,
    user_address: String,
    authority: String,
}

// Response structure
#[derive(Serialize, Debug)]
struct Response {
    tx_hash: String,
}

#[derive(Serialize, Debug)]
struct ErrorResponse {
    error: String,
}

#[derive(Serialize, Debug)]
struct HealthResponse {
    status: String,
}

sol!(
    #[sol(rpc)]
    ClaimBatchProcessor,
    "../out/ClaimBatchProcessor.sol/ClaimBatchProcessor.json",
);

fn check_authority(
    user: impl AsRef<str>,
    authority: impl AsRef<str>,
    msg: impl AsRef<[u8]>,
) -> Result<bool> {
    let user = user.as_ref().parse::<Address>()?;

    let sig: PrimitiveSignature = authority.as_ref()[2..].parse()?;
    let recovered = sig.recover_address_from_msg(&msg)?;

    Ok(recovered.to_ascii_lowercase() == user.to_ascii_lowercase())
}

/// Handles HTTP requests for batch claiming rewards
///
/// # Arguments
/// * `payload` - JSON payload containing batch claim details
/// * `contract` - Reference to the ClaimBatchProcessor contract
#[tracing::instrument(skip(contract))]
async fn handle_batch_claim<T: Transport + Clone, P: Provider<T, Ethereum>>(
    Json(payload): Json<BatchClaimRequest>,
    contract: Arc<ClaimBatchProcessorInstance<T, P, Ethereum>>,
) -> impl IntoResponse {
    match batch_claim(payload, contract).await {
        Ok(response) => (StatusCode::OK, Json(response)).into_response(),
        Err(e) => {
            tracing::error!("Batch claim failed: {}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(ErrorResponse {
                    error: e.to_string(),
                }),
            )
                .into_response()
        }
    }
}

/// Processes a batch claim request for multiple rewards
///
/// # Arguments
/// * `payload` - Batch claim request details
/// * `contract` - Reference to the ClaimBatchProcessor contract
/// * `provider` - Ethereum network provider
///
/// # Returns
/// * `Result<Response>` - Transaction hash of the batch claim
#[tracing::instrument(skip(contract))]
async fn batch_claim<T: Transport + Clone, P: Provider<T, Ethereum>>(
    payload: BatchClaimRequest,
    contract: Arc<ClaimBatchProcessorInstance<T, P, Ethereum>>,
) -> Result<Response> {
    let token_ids = payload
        .token_ids
        .clone()
        .into_iter()
        .map(|(k, mut v)| {
            v.sort();
            (k, v)
        })
        .collect::<BTreeMap<String, Vec<String>>>();

    // Create sorted JSON for authority verification
    let auth_payload = json!({
        "amount": payload.amount,
        "proof": payload.proof,
        "signature": payload.signature,
        "tokenIds": token_ids,
        "userAddress": payload.user_address
    });

    let msg = serde_json::to_string(&auth_payload)?;

    #[cfg(not(feature = "dev"))]
    if !check_authority(&payload.user_address, &payload.authority, msg.as_bytes())? {
        tracing::warn!("Invalid authority for user: {}", payload.user_address);
        return Err(eyre!("Invalid authority"));
    }

    // Decode args
    let proof: Vec<FixedBytes<32>> = payload
        .proof
        .iter()
        .map(|p| p.parse::<FixedBytes<32>>())
        .collect::<Result<Vec<_>, _>>()?;
    let signature = payload.signature.parse::<Bytes>()?;

    // Convert token_ids map to vectors for contract call
    let (nfts, token_ids): (Vec<Address>, Vec<Vec<U256>>) = payload
        .token_ids
        .into_iter()
        .map(|(nft, ids)| {
            Ok((
                nft.parse::<Address>()?,
                ids.into_iter()
                    .map(|id| U256::from_str_radix(&id, 10))
                    .collect::<Result<Vec<_>, _>>()?,
            ))
        })
        .collect::<Result<Vec<_>>>()?
        .into_iter()
        .unzip();

    tracing::debug!("token_ids: {:?}", token_ids);
    tracing::debug!("amount: {:?}", payload.amount);
    tracing::debug!("proof: {:?}", proof);
    tracing::debug!("signature: {:?}", signature);
    tracing::debug!("user_address: {:?}", payload.user_address);
    tracing::debug!("nfts: {:?}", nfts);

    let tx = contract.claim(
        token_ids,
        U256::from_str_radix(&payload.amount, 10)?,
        proof,
        signature,
        payload.user_address.parse::<Address>()?,
        nfts,
    );

    // Check if transaction would revert by estimating gas
    #[cfg(not(feature = "dev"))]
    {
        let tx = tx.send().await;
        let tx = tx.map_err(|e| {
            tracing::error!("Failed to send batch claim transaction: {}", e);
            eyre!("Failed to send batch claim transaction: {}", e)
        })?;

        Ok(Response {
            tx_hash: format!("{:?}", tx.tx_hash()),
        })
    }
    #[cfg(feature = "dev")]
    {
        Ok(Response {
            tx_hash: "0x123".to_string(),
        })
    }
}

async fn health_check() -> impl IntoResponse {
    (
        StatusCode::OK,
        Json(HealthResponse {
            status: "healthy".to_string(),
        }),
    )
}

#[tokio::main]
async fn main() -> Result<()> {
    // Install error hooks with backtrace support
    if std::env::var("RUST_BACKTRACE").is_err() {
        std::env::set_var("RUST_BACKTRACE", "1");
    }

    // Initialize tracing subscriber
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::DEBUG)
        .with_target(false)
        .init();

    let rpc_url = std::env::var("RPC_URL")?;
    let pod_id = std::env::var("POD_ID").unwrap();
    let pk_env_name = format!("PRIVATE_KEY_{}", pod_id);
    let private_key = std::env::var(pk_env_name)?;
    let batch_processor_contract_address = std::env::var("BATCH_PROCESSOR_CONTRACT_ADDRESS")?;

    // Setup provider and wallet
    let signer: PrivateKeySigner = private_key.parse().wrap_err("Invalid private key")?;
    let wallet: EthereumWallet = signer.into();

    let provider = Arc::new(
        ProviderBuilder::new()
            .with_recommended_fillers()
            .wallet(wallet)
            .on_http(rpc_url.parse().wrap_err("Invalid RPC URL")?),
    );

    let batch_processor_contract = Arc::new(ClaimBatchProcessor::new(
        batch_processor_contract_address
            .parse()
            .wrap_err("Invalid batch processor contract address")?,
        provider,
    ));

    // Setup router
    let app = Router::new().route("/healthz", get(health_check)).route(
        "/batch-claim",
        post(move |payload| handle_batch_claim(payload, batch_processor_contract.clone())),
    );

    // Start server
    tracing::info!("Server running on http://localhost:3000");
    axum::serve(tokio::net::TcpListener::bind("0.0.0.0:3000").await?, app).await?;

    Ok(())
}
