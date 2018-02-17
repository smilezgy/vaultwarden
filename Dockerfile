# Using multistage build: 
# 	https://docs.docker.com/develop/develop-images/multistage-build/
# 	https://whitfin.io/speeding-up-rust-docker-builds/
########################## BUILD IMAGE  ##########################
# We need to use the Rust build image, because
# we need the Rust compiler and Cargo tooling
FROM rustlang/rust:nightly as build

# Install the database libraries, in this case just sqlite3
RUN apt-get update && \
	apt-get install -y sqlite3

# Creates a dummy project used to grab dependencies
RUN USER=root cargo new --bin app
WORKDIR /app

# Copies over *only* your manifests and vendored dependencies
COPY ./Cargo.* ./
COPY ./libs ./libs

# Builds your dependencies and removes the
# dummy project, except the target folder
# This folder contains the compiled dependencies
RUN cargo build --release
RUN find . -not -path "./target*" -delete

# Copies the complete project
# To avoid copying unneeded files, use .dockerignore
COPY . .

# Builds again, this time it'll just be
# your actual source files being built
RUN cargo build --release

######################## RUNTIME IMAGE  ########################
# Create a new stage with a minimal image
# because we already have a binary built
FROM debian:stretch-slim

# Install needed libraries
RUN apt-get update && \
 	apt-get install -y sqlite3 openssl libssl-dev

RUN mkdir /data
VOLUME /data
EXPOSE 80

# Copies the files from the context (env file and web-vault)
# and the binary from the "build" stage to the current stage
COPY .env .
COPY web-vault ./web-vault
COPY --from=build app/target/release/bitwarden_rs .

# Configures the startup!
# Use production to disable Rocket logging
#CMD ROCKET_ENV=production ./bitwarden_rs
CMD ROCKET_ENV=staging ./bitwarden_rs