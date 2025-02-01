FROM nvidia/cuda:12.0.1-devel-ubuntu22.04

# Environment variables
ENV LAMMPS_VERSION=stable_23Jun2022 \
    # Support both T4 (sm_75) and A100 (sm_80)
    CUDA_ARCH="sm_75 sm_80" \
    DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    cmake \
    git \
    python3-dev \
    python3-pip \
    libfftw3-dev \
    libjpeg-dev \
    libpng-dev \
    openmpi-bin \
    libopenmpi-dev \
    awscli \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Clone and build LAMMPS
WORKDIR /opt
RUN git clone -b ${LAMMPS_VERSION} https://github.com/lammps/lammps.git

# Build LAMMPS with GPU support
WORKDIR /opt/lammps/cmake
RUN mkdir build \
    && cd build \
    && cmake ../cmake \
        -D CMAKE_BUILD_TYPE=Release \
        -D BUILD_MPI=yes \
        -D BUILD_OMP=yes \
        -D PKG_GPU=yes \
        -D PKG_KOKKOS=yes \
        -D Kokkos_ENABLE_CUDA=yes \
        -D Kokkos_ARCH_TURING75=yes \
        -D Kokkos_ARCH_AMPERE80=yes \
        -D PKG_MOLECULE=yes \
        -D PKG_KSPACE=yes \
        -D PKG_MANYBODY=yes \
        -D PKG_MC=yes \
        -D PKG_MISC=yes \
        -D PKG_RIGID=yes \
        -D PKG_EXTRA-COMPUTE=yes \
        -D PKG_EXTRA-DUMP=yes \
        -D PKG_EXTRA-FIX=yes \
        -D PKG_EXTRA-PAIR=yes \
    && make -j$(nproc)

# Create directories for simulation and scripts
RUN mkdir -p /simulation /opt/scripts

# Copy scripts
COPY scripts/checkpoint.sh /opt/scripts/
COPY scripts/spot-termination-handler.sh /opt/scripts/

# Make scripts executable
RUN chmod +x /opt/scripts/*.sh

# Add LAMMPS to PATH
ENV PATH="/opt/lammps/cmake/build:${PATH}"

# Create working directory for simulations
WORKDIR /simulation

# Default command runs spot termination handler in background
CMD ["/bin/bash", "-c", "/opt/scripts/spot-termination-handler.sh & exec /bin/bash"]