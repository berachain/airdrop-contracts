import subprocess
from typing import Dict, List, Optional
import re
import os
import sys
from collections import defaultdict
from config import *

def run_script(
    script_path: str, config: Dict[str, str] = {}, env: Dict[str, str] = {}
) -> Dict:
    """
    Run a forge script with environment variables.

    Args:
        script_path: Path to the forge script
        config: Configuration dictionary with rpcUrl and broadcast options
        env: Environment variables dictionary

    Returns:
        CompletedProcess instance with return code and output
    """
    cmd = ["forge", "script", script_path]

    if "rpcUrl" in config:
        cmd.extend(["--rpc-url", config["rpcUrl"]])

    if config.get("broadcast", False):
        cmd.append("--broadcast")

    env["PATH"] = os.environ["PATH"]

    # Use Popen to stream stdout and stderr
    process = subprocess.Popen(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env
    )

    # Stream stdout and stderr
    stdout_lines = []
    stderr_lines = []
    for stdout_line in iter(process.stdout.readline, ""):
        print(stdout_line, end="")
        stdout_lines.append(stdout_line)
    for stderr_line in iter(process.stderr.readline, ""):
        print(stderr_line, end="", file=sys.stderr)
        stderr_lines.append(stderr_line)

    process.stdout.close()
    process.stderr.close()
    return_code = process.wait()

    # Combine stdout and stderr for parsing
    output = "".join(stdout_lines)
    error_output = "".join(stderr_lines)

    if return_code != 0:
        raise subprocess.CalledProcessError(
            return_code, cmd, output=output, stderr=error_output
        )

    return parse_output(output)


def parse_output(output: str) -> Dict:
    """
    Parse output lines matching pattern {nested_key}:{value} and return as nested dictionary.
    Example input: "contract.proxy.address:0x123..."
    Will return: {"contract": {"proxy": {"address": "0x123..."}}}

    Args:
        output: String output to parse

    Returns:
        Nested dictionary of parsed values
    """
    result = defaultdict(dict)
    pattern = r"^([^\s:]+):(.+)$"

    for line in output.splitlines():
        line = line.strip()
        match = re.match(pattern, line)
        if match:
            nested_key, value = match.groups()
            keys = nested_key.split(".")
            current_dict = result
            for key in keys[:-1]:
                current_dict = current_dict.setdefault(key, {})
            current_dict[keys[-1]] = value.strip()

    return dict(result)


def deploy_mock_token():
    """
    Deploy MockToken on ethereum
    """
    return run_script(
        "script/MockToken.s.sol",
        config={"rpcUrl": ETHEREUM_RPC_URL},
        env={"CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY},
    )


def setup_eid_for_wrapped_nft(pair, broadcast: bool = False):
    """
    Setup EID for WrappedNFT on ethereum and berachain
    """
    run_script(
        "script/WrappedNFT.s.sol:WrappedNFTEidSetupScript",
        config={"rpcUrl": ETHEREUM_RPC_URL, "broadcast": broadcast},
        env={
            "ADDRESS_WRAPPED_NFT": pair["ethereum"],
            "ADDRESS_PEER": pair["berachain"],
            "EID": str(LZ_EID_BERACHAIN),
            "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
        },
    )


def deploy_wrapped_nft(tokens: List[str], broadcast: bool = False):
    """
    Deploy WrappedNFT for erc1155 on ethereum and berachain
    """
    rpc_url = {
        "ethereum": ETHEREUM_RPC_URL,
        "berachain": BERACHAIN_RPC_URL,
    }

    lz_endpoint = {
        "ethereum": LZ_ENDPOINT_ETHEREUM,
        "berachain": LZ_ENDPOINT_BERACHAIN,
    }

    result = defaultdict(dict)

    for token in tokens:
        result[token] = {}
        for chain in ["ethereum", "berachain"]:
            result[token][chain] = run_script(
                "script/WrappedNFT.s.sol:WrappedNFTScript",
                config={"rpcUrl": rpc_url[chain], "broadcast": broadcast},
                env={
                    "ADDRESS_ORIGIN": (
                        token
                        if chain == "ethereum"
                        else "0x0000000000000000000000000000000000000000"
                    ),
                    "ADDRESS_LZ_ENDPOINT": lz_endpoint[chain],
                    "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
                },
            )
    return dict(result)


def deploy_bera_nft(tokens: List[any], broadcast: bool = False):
    info = {}
    for token in tokens:
        result = run_script(
            "script/BeraNft.s.sol:BeraNftScript",
            config={"rpcUrl": BERACHAIN_RPC_URL, "broadcast": broadcast},
            env={
                "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
                "TOKEN_NAME": token["name"],
                "TOKEN_SYMBOL": token["symbol"],
                "LZ_ENDPOINT": LZ_ENDPOINT_BERACHAIN,
            },
        )
        info[token["address"]] = result
    return info


def deploy_nft_adapter(tokens: List[any], broadcast: bool = False):
    info = {}
    for token in tokens:
        result = run_script(
            "script/OnftAdapter.s.sol:OnftAdapterScript",
            config={"rpcUrl": ETHEREUM_RPC_URL, "broadcast": broadcast},
            env={
                "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
                "ADDRESS_ORIGIN": token["address"],
                "ADDRESS_LZ_ENDPOINT": LZ_ENDPOINT_ETHEREUM,
            },
        )
        info[token["address"]] = result
    return info


def set_nft_adapter_eid(tokens: List[any], broadcast: bool = False):
    for token in tokens:
        run_script(
            "script/OnftAdapter.s.sol:OnftAdapterEidSetupScript",
            config={"rpcUrl": ETHEREUM_RPC_URL, "broadcast": broadcast},
            env={
                "ADDRESS_BERA_NFT": token["address"],
                "ADDRESS_PEER": token["peerAddress"],
                "EID": str(LZ_EID_BERACHAIN),
                "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
            },
        )

def set_nft_peer_eid(tokens: List[any], broadcast: bool = False):
    for token in tokens:
        run_script(
            "script/BeraNft.s.sol:BeraNftEidSetupScript",
            config={"rpcUrl": BERACHAIN_RPC_URL, "broadcast": broadcast},
            env={
                "ADDRESS_BERA_NFT": token["address"],
                "ADDRESS_PEER": token["peerAddress"],
                "EID": str(LZ_EID_ETHEREUM),
                "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
            },
        )

def deploy_distributor(broadcast: bool = False):
    """
    Deploy Distributor on berachain
    """

    return run_script(
        "script/Distributor.s.sol:DistributorScript",
        config={"rpcUrl": BERACHAIN_RPC_URL, "broadcast": broadcast},
        env={"CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY, "ADDRESS_SIGNER": ADDRESS_SIGNER},
    )

def deploy_streaming_nft(credential_nft: str, blacklisted_token_ids: List[str], allocation_per_nft: int, broadcast: bool = False):
    """
    Deploy StreamingNFT on berachain
    """
    return run_script(
        "script/Distributor.s.sol:StreamingNFTScript",
        config={"rpcUrl": BERACHAIN_RPC_URL, "broadcast": broadcast},
        env={
            "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
            "ADDRESS_CREDENTIAL_NFT": credential_nft,
            "BLACKLISTED_TOKEN_IDS": ",".join(blacklisted_token_ids),
            "ALLOCATION_PER_NFT": allocation_per_nft,
        },
    )


def deploy_claim_batch_processor(distributor: str, broadcast: bool = False):
    """
    Deploy ClaimBatchProcessor on berachain
    """
    return run_script(
        "script/Distributor.s.sol:ClaimBatchProcessorScript",
        config={"rpcUrl": BERACHAIN_RPC_URL, "broadcast": broadcast},
        env={
            "CONFIG_DEPLOYER": DEPLOYER_PRIVATE_KEY,
            "ADDRESS_DISTRIBUTOR": distributor,
        },
    )


if __name__ == "__main__":
    broadcast = False
    result = {}
    result |= deploy_distributor(broadcast)

    print(result)
    result |= deploy_claim_batch_processor(result["address"]["distributor"], broadcast)
    print(result)

    result["address"]["streamingNFT"] = {} 
    for token, blacklisted_token_ids, allocation_per_nft in [
        ("0x6c9612Beb7be2c16359803898df830C8b9b5Cde7", blacklisted_bong_bears, ts_bong_bears), # bong bears
        ("0x30e83a174e4Bd15eA94B5404D3341D0c46a6F5c4", empty_blacklist, ts_bond_bears), # bond bears
    ]:
        ret = deploy_streaming_nft(token, blacklisted_token_ids, allocation_per_nft, broadcast)
        result["address"]["streamingNFT"][token] = ret["address"]["streamingNFT"]
        print(result)

    # run_script(
    #     "script/ERC1155Send.s.sol:ERC1155SendScript",
    #     config={"rpcUrl": ETHEREUM_RPC_URL, "broadcast": True},
    #     env={
    #         "ADDRESS_WRAPPED_NFT": "0xf6dea918096AE14B0C55DBbD7aBC38c44df3F0cC",
    #         "TOKEN_ID": "340282366920938463463374607431768211456",
    #         "EID": str(LZ_EID_BERACHAIN),
    #         "CONFIG_SENDER": DEPLOYER_PRIVATE_KEY,
    #     },
    # )

    # run_script(
    #     "script/ERC1155Send.s.sol:ERC721SendScript",
    #     config={"rpcUrl": ETHEREUM_RPC_URL, "broadcast": True},
    #     env={
    #         "ADDRESS_ADAPTER": "0xC5C7516452A2e87Fd6223cbb7A8c9eBfB4428220",
    #         "ADDRESS_ORIGIN": "0x81112D4A0389AFBE159F39a5b048602cEb221285",
    #         "TOKEN_ID": "0",
    #         "EID": str(LZ_EID_BERACHAIN),
    #         "CONFIG_SENDER": DEPLOYER_PRIVATE_KEY,
    #     },
    # )
