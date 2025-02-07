# Use Rust 1.75.0 as the base image to match the toolchain version used in other services
FROM rust:1.75.0-slim-bullseye as builder

# Install required system dependencies including Node.js and npm
RUN apt-get update && \
    apt-get install -y \
    pkg-config \
    libssl-dev \
    curl \
    git \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Create and set the working directory
WORKDIR /usr/src

# Copy the entire project
COPY . .

# Install Forge
RUN curl -L https://foundry.paradigm.xyz | bash
RUN $HOME/.foundry/bin/foundryup

# Build Forge project
RUN $HOME/.foundry/bin/forge build

WORKDIR /usr/src/paymaster

# Build the release binary
RUN cargo build --release

# Create the runtime image
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y \
    ca-certificates \
    libssl1.1 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary from builder
COPY --from=builder /usr/src/paymaster/target/release/paymaster /usr/local/bin/

# Create a non-root user to run the service
RUN useradd -m -u 1001 -U paymaster
USER paymaster

# Expose the service port
EXPOSE 3000

# Set environment variables
ENV RUST_BACKTRACE=1

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/healthz || exit 1

# Run the binary
CMD ["paymaster"]