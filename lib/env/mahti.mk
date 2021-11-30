# -*-makefile-*-
#
# environment on mathi@CSC
#


CSCPROJECT   = project_2003288
# CSCPROJECT   = project_2002688
# CSCPROJECT   = project_2003093
# CSCPROJECT   = project_2002982
WORKHOME      = ${shell realpath ${PWD}/work}
LOCAL_SCRATCH = /scratch/${CSCPROJECT}
APPLHOME      = /projappl/project_2003093/
OPUSHOME      = /projappl/nlpl/data/OPUS
MOSESHOME     = ${APPLHOME}/install/mosesdecoder
MOSESSCRIPTS  = ${MOSESHOME}/scripts
EFLOMAL_HOME  = ${APPLHOME}/install/eflomal/
MARIAN_HOME   = ${APPLHOME}/install/marian-dev/build/
MARIAN        = ${MARIAN_HOME}
SPM_HOME      = ${MARIAN_HOME}
HPC_QUEUE     = medium
SUBMIT_PREFIX = submitcpu
GPU           = a100
WALLTIME      = 36

## select queue depending on the number of GPUs allocated
ifeq (${NR_GPUS},1)
 HPC_GPUQUEUE  = gpusmall
else ifeq (${NR_GPUS},2)
 HPC_GPUQUEUE  = gpusmall
else
 HPC_GPUQUEUE  = gpumedium
endif 

export PATH := ${APPLHOME}/bin:${PATH}


CPU_MODULES   = gcc/10.3.0 cuda/11.4.2 cudnn/8.0.4.30-11.0-linux-x64 openblas/0.3.14-omp openmpi/4.0.5-cuda
GPU_MODULES   = gcc/10.3.0 cuda/11.4.2 cudnn/8.0.4.30-11.0-linux-x64 openblas/0.3.14-omp openmpi/4.0.5-cuda
LOAD_CPU_ENV  = module load ${CPU_MODULES}
LOAD_GPU_ENV  = module load ${GPU_MODULES}


## extra SLURM directives (up to 5 variables)
HPC_EXTRA1 = \#SBATCH --account=${CSCPROJECT}


## setup for compiling marian-nmt

MARIAN_BUILD_MODULES  = gcc/10.3.0 cuda/11.4.2 cudnn/8.0.4.30-11.0-linux-x64 cmake/3.18.4 openblas/0.3.14-omp openmpi/4.0.5-cuda
LOAD_MARIAN_BUILD_ENV = module purge && module load ${MARIAN_BUILD_MODULES}
MARIAN_BUILD_OPTIONS  = -DTcmalloc_INCLUDE_DIR=/appl/spack/v016/install-tree/gcc-10.3.0/gperftools-2.7-ibnifm/include \
			-DTcmalloc_LIBRARY=/appl/spack/v016/install-tree/gcc-10.3.0/gperftools-2.7-ibnifm/lib/libtcmalloc.so \
			-DTCMALLOC_LIB=/appl/spack/v016/install-tree/gcc-10.3.0/gperftools-2.7-ibnifm/lib/libtcmalloc.so \
			-DCUDNN=ON \
			-DCOMPILE_CPU=ON \
			-DCOMPILE_CUDA_SM80=ON \
			-DCOMPILE_CUDA=ON \
			-DCOMPILE_CUDA_SM35=OFF \
			-DCOMPILE_CUDA_SM50=OFF \
			-DCOMPILE_CUDA_SM60=OFF \
			-DCOMPILE_CUDA_SM70=OFF \
			-DCOMPILE_CUDA_SM75=OFF \
			-DCOMPILE_AVX512=OFF \
			-DUSE_MPI=ON \
			-DUSE_DOXYGEN=OFF \
			-DCOMPILE_TURING=OFF \
			-DCOMPILE_VOLTA=OFF \
			-DCOMPILE_PASCAL=OFF \
			-DUSE_FBGEMM=1 \
			-DFBGEMM_STATIC=1

