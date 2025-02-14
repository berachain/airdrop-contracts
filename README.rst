################
Berachain Claims
################

A protocol for managing NFT-based vesting streams and social verification rewards on Berachain.

Core Components
==============

1. **StreamingNFT Contract**: Manages NFT-gated vesting streams
2. **Distributor Contract**: Handles reward distribution with Merkle proofs and ECDSA signatures
3. **ClaimBatchProcessor**: Optimizes gas usage for batch claiming operations

Features
========

StreamingNFT Contract
--------------------
- NFT-gated vesting streams
- Configurable vesting parameters:
    - Duration
    - Instant unlock percentage
    - Per-NFT allocation
- Support for both native and ERC20 tokens
- Security features:
    - Pausable functionality
    - Reentrancy protection
    - Two-step ownership transfers

Distributor Contract
-------------------
- Merkle-based reward distribution
- ECDSA signature verification
- Batch claim support

ClaimBatchProcessor Contract
-------------------------
- Combined batch processing for streams and rewards
- Atomic execution of multiple claims
- Ownership validation for NFT-based claims
- Gas-optimized batch operations
- Integration with StreamingNFT and Distributor contracts

Installation
===========

Smart Contracts
-------------

.. code-block:: bash

    # Install dependencies
    forge install

    # Build contracts
    forge build

Usage
=====

Deploy Contracts
--------------

.. code-block:: bash

    forge script script/StreamingNFT.s.sol:StreamingNFTScript --rpc-url <your_rpc_url> --broadcast

Development
==========

Testing
-------

.. code-block:: bash

    # Run smart contract tests
    forge test


Architecture
===========

Smart Contracts
-------------
- ``StreamingNFT.sol``: Main vesting contract
- ``Distributor1.sol``: Reward distribution contract
- ``Transferable.sol``: Base contract for token transfers
- ``ClaimBatchProcessor.sol``: Batch claim processor