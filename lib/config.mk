# -*-makefile-*-
#
# model configurations
#

## various ways of setting the model languages

## (1) explicitly set source and target languages, for example:
##     SRCLANGS="da no sv" TRGLANGS="fi da"
##
## (2) specify language pairs, for example:
##     LANGPAIRS="de-en fi-sv da-es"
##     this will set SRCLANGS="de fi da" TRGLANGS="en sv es"
##


## if LANGPAIRS are set and the model is not supposed to be SYMMETRIC
## then set SRCLANGS and TRGLANGS to the languages in LANGPAIRS
ifdef LANGPAIRS
  SRCLANGS ?= ${sort ${shell echo "${LANGPAIRS}" | tr ' ' "\n" | cut -f1 -d '-'}}
  TRGLANGS ?= ${sort ${shell echo "${LANGPAIRS}" | tr ' ' "\n" | cut -f2 -d '-'}}
endif


## final default is sv-fi
SRCLANGS ?= sv
TRGLANGS ?= fi


## set SRC and TRG unless they are specified already
ifneq (${words ${SRCLANGS}},1)
  SRC ?= multi
else
  SRC = ${SRCLANGS}
endif
ifneq (${words ${TRGLANGS}},1)
  TRG ?= multi
else
  TRG = ${TRGLANGS}
endif


## OLD: set to first and last lang
## --> this makes the evaluation look like it is one lang-pair
##
# SRC ?= ${firstword ${SRCLANGS}}
# TRG ?= ${lastword ${TRGLANGS}}


## SKIP_LANGPAIRS can be used to skip certain language pairs
## in data preparation for multilingual models
## ---> this can be good to skip BIG language pairs
##      that would very much dominate all the data
## must be a pattern that can be matched by egrep
## e.g. en-de|en-fr

SKIP_LANGPAIRS ?= "nothing"


## set SHUFFLE_DATA if you want to shuffle data for 
## each language pair to be added to the training data
## --> especially useful in connection with FIT_DATA_SIZE
##  
# SHUFFLE_DATA = 1

## set FIT_DATA_SIZE to a specific value to fit the training data
## to a certain number of lines for each language pair in the collection
## --> especially useful for multilingual models for balancing the 
##     the size for each language pair
## the script does both, over- and undersampling
##
# FIT_DATA_SIZE = 100000

## maximum number of repeating the same data set 
## in oversampling
MAX_OVER_SAMPLING ?= 50


## set CHECK_TRAINDATA_SIZE if you want to check that each
## bitext has equal number of lines in source and target
## ---> this only prints a warning if not
##
# CHECK_TRAINDATA_SIZE


# sorted languages and langpair used to match resources in OPUS
SORTLANGS   = $(sort ${SRC} ${TRG})
SPACE       = $(empty) $(empty)
LANGPAIR    = ${firstword ${SORTLANGS}}-${lastword ${SORTLANGS}}
LANGSRCSTR  = ${subst ${SPACE},+,$(SRCLANGS)}
LANGTRGSTR  = ${subst ${SPACE},+,$(TRGLANGS)}
LANGPAIRSTR = ${LANGSRCSTR}-${LANGTRGSTR}


## for monolingual things
LANGS ?= ${SRCLANGS}
LANGID ?= ${firstword ${LANGS}}
LANGSTR ?= ${subst ${SPACE},+,$(LANGS)}


## for same language pairs: add numeric extension
## (this is neccessary to keep source and target files separate)
ifeq (${SRC},$(TRG))
  SRCEXT = ${SRC}1
  TRGEXT = ${SRC}2
else
  SRCEXT = ${SRC}
  TRGEXT = ${TRG}
endif

## set a flag to use target language labels
## in multi-target models
ifneq (${words ${TRGLANGS}},1)
  USE_TARGET_LABELS = 1
endif


## set additional argument options for opus_read (if it is used)
## e.g. OPUSREAD_ARGS = -a certainty -tr 0.3
OPUSREAD_ARGS = 

## ELRA corpora
ELRA_CORPORA = ${patsubst %/latest/xml/${LANGPAIR}.xml.gz,%,\
		${patsubst ${OPUSHOME}/%,%,\
		${shell ls ${OPUSHOME}/ELRA-*/latest/xml/${LANGPAIR}.xml.gz 2>/dev/null}}}

## exclude certain data sets
## TODO: include ELRA corpora
EXCLUDE_CORPORA ?= WMT-News MPC1 ${ELRA_CORPORA}

## all of OPUS (NEW: don't require MOSES format)
OPUSCORPORA  = $(filter-out ${EXCLUDE_CORPORA} ,${patsubst %/latest/xml/${LANGPAIR}.xml.gz,%,\
		${patsubst ${OPUSHOME}/%,%,\
		${shell ls ${OPUSHOME}/*/latest/xml/${LANGPAIR}.xml.gz 2>/dev/null}}})

## monolingual data
OPUSMONOCORPORA = $(filter-out ${EXCLUDE_CORPORA} ,${patsubst %/latest/mono/${LANGID}.txt.gz,%,\
		${patsubst ${OPUSHOME}/%,%,\
		${shell ls ${OPUSHOME}/*/latest/mono/${LANGID}.txt.gz}}})


## all languages in OPUS (requires the opus-langs.txt file)
ifneq (${wildcard opus-langs.txt},)
  OPUSLANGS = ${filter-out simple,${shell head -1 opus-langs.txt}}
endif


ALL_LANG_PAIRS = ${shell ls ${WORKHOME} | grep -- '-' | grep -v old}
ALL_BILINGUAL_MODELS = ${shell echo '${ALL_LANG_PAIRS}' | tr ' ' "\n" |  grep -v -- '\+'}
ALL_MULTILINGUAL_MODELS = ${shell echo '${ALL_LANG_PAIRS}' | tr ' ' "\n" | grep -- '\+'}


## size of dev data, test data and BPE merge operations
## NEW default size = 2500 (keep more for training for small languages)

DEVSIZE     = 2500
TESTSIZE    = 2500

## NEW: significantly reduce devminsize
## (= absolute minimum we need as devdata)
## NEW: define an alternative small size for DEV and TEST
## OLD DEVMINSIZE:
# DEVMINSIZE  = 1000

DEVSMALLSIZE  = 1000
TESTSMALLSIZE = 1000
DEVMINSIZE    = 250


##----------------------------------------------------------------------------
## train/dev/test data
##----------------------------------------------------------------------------

## dev/test data: default = Tatoeba otherwise, GlobalVoices, JW300, GNOME or bibl-uedin
## - check that data exist
## - check that there are at least 2 x DEVMINSIZE examples
## TODO: this does not work well for multilingual models!
## TODO: find a better solution than looking into *.info files (use OPUS API?)
## ---> query for corpora bigger than a certain size and look for a suitable test/dev corpus

ifneq ($(wildcard ${OPUSHOME}/Tatoeba/latest/moses/${LANGPAIR}.txt.zip),)
ifeq ($(shell if (( `head -1 ${OPUSHOME}/Tatoeba/latest/info/${LANGPAIR}.txt.info` \
		    > $$((${DEVMINSIZE} + ${DEVMINSIZE})) )); then echo "ok"; fi),ok)
  DEVSET = Tatoeba
endif
endif

## backoff to GlobalVoices
ifndef DEVSET
ifneq ($(wildcard ${OPUSHOME}/GlobalVoices/latest/moses/${LANGPAIR}.txt.zip),)
ifeq ($(shell if (( `head -1 ${OPUSHOME}/GlobalVoices/latest/info/${LANGPAIR}.txt.info` \
		    > $$((${DEVMINSIZE} + ${DEVMINSIZE})) )); then echo "ok"; fi),ok)
  DEVSET = GlobalVoices
endif
endif
endif

## backoff to infopankki
ifndef DEVSET
ifneq ($(wildcard ${OPUSHOME}/infopankki/latest/moses/${LANGPAIR}.txt.zip),)
ifeq ($(shell if (( `head -1 ${OPUSHOME}/infopankki/latest/info/${LANGPAIR}.txt.info` \
		    > $$((${DEVMINSIZE} + ${DEVMINSIZE})) )); then echo "ok"; fi),ok)
  DEVSET = infopankki
endif
endif
endif

## backoff to JW300
ifndef DEVSET
ifneq ($(wildcard ${OPUSHOME}/JW300/latest/xml/${LANGPAIR}.xml.gz),)
ifeq ($(shell if (( `sed -n 2p ${OPUSHOME}/JW300/latest/info/${LANGPAIR}.info` \
		    > $$((${DEVMINSIZE} + ${DEVMINSIZE})) )); then echo "ok"; fi),ok)
  DEVSET = JW300
endif
endif
endif

## otherwise: bible-uedin
ifndef DEVSET
  DEVSET = bible-uedin
endif


## increase dev/test sets for Tatoeba (very short sentences!)
ifeq (${DEVSET},Tatoeba)
  DEVSIZE = 5000
  TESTSIZE = 5000
endif


## in case we want to use some additional data sets
# EXTRA_TRAINSET =

## TESTSET= DEVSET, TRAINSET = OPUS - WMT-News,DEVSET.TESTSET
TESTSET  ?= ${DEVSET}
TRAINSET ?= $(filter-out ${EXCLUDE_CORPORA} ${DEVSET} ${TESTSET},${OPUSCORPORA} ${EXTRA_TRAINSET})
MONOSET  ?= $(filter-out ${EXCLUDE_CORPORA} ${DEVSET} ${TESTSET},${OPUSMONOCORPORA} ${EXTRA_TRAINSET})

## 1 = use remaining data from dev/test data for training
USE_REST_DEVDATA ?= 1


##----------------------------------------------------------------------------
## pre-processing and vocabulary
##----------------------------------------------------------------------------

SUBWORDS   ?= spm
BPESIZE    ?= 32000
SRCBPESIZE ?= ${BPESIZE}
TRGBPESIZE ?= ${BPESIZE}

VOCABSIZE  ?= $$((${SRCBPESIZE} + ${TRGBPESIZE} + 1000))

## for document-level models
CONTEXT_SIZE = 100

## pre-processing type
# PRE     = norm
PRE       = simple
PRE_SRC   = ${SUBWORDS}${SRCBPESIZE:000=}k
PRE_TRG   = ${SUBWORDS}${TRGBPESIZE:000=}k


##-------------------------------------
## default name of the data set (and the model)
##-------------------------------------

ifndef DATASET
  DATASET = opus
endif

ifndef BPEMODELNAME
  BPEMODELNAME = opus
endif

##-------------------------------------
## OLD OLD OLD
## name of the data set (and the model)
##  - single corpus = use that name
##  - multiple corpora = opus
## add also vocab size to the name
##-------------------------------------

ifndef OLDDATASET
ifeq (${words ${TRAINSET}},1)
  OLDDATASET = ${TRAINSET}
else
  OLDDATASET = opus
endif
endif



## DATADIR = directory where the train/dev/test data are
## WORKDIR = directory used for training

DATADIR  = ${WORKHOME}/data
WORKDIR  = ${WORKHOME}/${LANGPAIRSTR}
MODELDIR = ${WORKHOME}/models/${LANGPAIRSTR}
SPMDIR   = ${WORKHOME}/SentencePieceModels

## data sets
TRAIN_BASE = ${WORKDIR}/train/${DATASET}
TRAIN_SRC  = ${TRAIN_BASE}.src
TRAIN_TRG  = ${TRAIN_BASE}.trg
TRAIN_ALG  = ${TRAIN_BASE}${TRAINSIZE}.${PRE_SRC}-${PRE_TRG}.src-trg.alg.gz

## training data in local space
LOCAL_TRAIN_SRC = ${TMPDIR}/${LANGPAIRSTR}/train/${DATASET}.src
LOCAL_TRAIN_TRG = ${TMPDIR}/${LANGPAIRSTR}/train/${DATASET}.trg
LOCAL_MONO_DATA = ${TMPDIR}/${LANGSTR}/train/${DATASET}.mono

## dev and test data come from one specific data set
## if we have a bilingual model

ifeq (${words ${SRCLANGS}},1)
ifeq (${words ${TRGLANGS}},1)

  DEV_SRC   = ${WORKDIR}/val/${DEVSET}.src
  DEV_TRG   = ${WORKDIR}/val/${DEVSET}.trg

  TEST_SRC  = ${WORKDIR}/test/${TESTSET}.src
  TEST_TRG  = ${WORKDIR}/test/${TESTSET}.trg

  TESTSET_NAME = ${TESTSET}

endif
endif

## otherwise we give them a generic name

DEVSET_NAME  ?= opus-dev
TESTSET_NAME ?= opus-test

DEV_SRC   ?= ${WORKDIR}/val/${DEVSET_NAME}.src
DEV_TRG   ?= ${WORKDIR}/val/${DEVSET_NAME}.trg

TEST_SRC  ?= ${WORKDIR}/test/${TESTSET_NAME}.src
TEST_TRG  ?= ${WORKDIR}/test/${TESTSET_NAME}.trg


MODEL_SUBDIR =
MODEL        = ${MODEL_SUBDIR}${DATASET}${TRAINSIZE}.${PRE_SRC}-${PRE_TRG}
MODELTYPE    = transformer-align
NR           = 1

MODEL_BASENAME  = ${MODEL}.${MODELTYPE}.model${NR}
MODEL_VALIDLOG  = ${MODEL}.${MODELTYPE}.valid${NR}.log
MODEL_TRAINLOG  = ${MODEL}.${MODELTYPE}.train${NR}.log
MODEL_START     = ${WORKDIR}/${MODEL_BASENAME}.npz
MODEL_FINAL     = ${WORKDIR}/${MODEL_BASENAME}.npz.best-perplexity.npz
MODEL_VOCABTYPE = yml
MODEL_VOCAB     = ${WORKDIR}/${MODEL}.vocab.${MODEL_VOCABTYPE}
MODEL_DECODER   = ${MODEL_FINAL}.decoder.yml


## test set translation and scores

TEST_TRANSLATION = ${WORKDIR}/${TESTSET_NAME}.${MODEL}${NR}.${MODELTYPE}.${SRC}.${TRG}
TEST_EVALUATION  = ${TEST_TRANSLATION}.eval
TEST_COMPARISON  = ${TEST_TRANSLATION}.compare



## parameters for running Marian NMT

MARIAN_GPUS             = 0
MARIAN_EXTRA            = 
MARIAN_VALID_FREQ       = 10000
MARIAN_SAVE_FREQ        = ${MARIAN_VALID_FREQ}
MARIAN_DISP_FREQ        = ${MARIAN_VALID_FREQ}
MARIAN_EARLY_STOPPING   = 10
MARIAN_VALID_MINI_BATCH = 16
MARIAN_MAXI_BATCH       = 500
MARIAN_DROPOUT          = 0.1
MARIAN_MAX_LENGTH	= 500

MARIAN_DECODER_GPU    = -b 12 -n1 -d ${MARIAN_GPUS} --mini-batch 8 --maxi-batch 32 --maxi-batch-sort src \
			--max-length ${MARIAN_MAX_LENGTH} --max-length-crop
MARIAN_DECODER_CPU    = -b 12 -n1 --cpu-threads ${HPC_CORES} --mini-batch 8 --maxi-batch 32 --maxi-batch-sort src \
			--max-length ${MARIAN_MAX_LENGTH} --max-length-crop
MARIAN_DECODER_FLAGS = ${MARIAN_DECODER_GPU}

## TODO: currently marianNMT crashes with workspace > 26000
ifeq (${GPU},p100)
  MARIAN_WORKSPACE = 13000
else ifeq (${GPU},v100)
  # MARIAN_WORKSPACE = 30000
  # MARIAN_WORKSPACE = 26000
  MARIAN_WORKSPACE = 24000
  # MARIAN_WORKSPACE = 18000
  # MARIAN_WORKSPACE = 16000
else
  MARIAN_WORKSPACE = 10000
endif

## check whether we have GPUs available
## if not: use CPU mode for decoding
NVIDIA_SMI := ${shell which nvidia-smi 2>/dev/null}
ifneq ($(wildcard ${NVIDIA_SMI}),)
ifeq (${shell nvidia-smi | grep failed | wc -l},1)
  MARIAN = ${MARIANCPU}
  MARIAN_DECODER_FLAGS = ${MARIAN_DECODER_CPU}
  MARIAN_EXTRA = --cpu-threads ${HPC_CORES}
endif
else
  MARIAN = ${MARIANCPU}
  MARIAN_DECODER_FLAGS = ${MARIAN_DECODER_CPU}
  MARIAN_EXTRA = --cpu-threads ${HPC_CORES}
endif

## weights associated with training examples
ifneq ("$(wildcard ${TRAIN_WEIGHTS})","")
	MARIAN_TRAIN_WEIGHTS = --data-weighting ${TRAIN_WEIGHTS}
endif



### training a model with Marian NMT
##
## NR allows to train several models for proper ensembling
## (with shared vocab)
##
## DANGER: if several models are started at the same time
## then there is some racing issue with creating the vocab!

ifdef NR
  SEED=${NR}${NR}${NR}${NR}
else
  SEED=1234
endif



## list of all languages in OPUS
opus-langs.txt:
	wget -O $@.tmp http://opus.nlpl.eu/opusapi/?languages=true
	grep '",' $@.tmp | tr '",' '  ' | sort | tr "\n" ' ' | sed 's/  */ /g' > $@
	rm -f $@.tmp


## make some data size-specific configuration parameters
## TODO: is it OK to delete LOCAL_TRAIN data?

.PHONY: local-config
local-config: ${WORKDIR}/config.mk

SMALLEST_TRAINSIZE = 10000
SMALL_TRAINSIZE    = 100000
MEDIUM_TRAINSIZE   = 500000
LARGE_TRAINSIZE    = 1000000
LARGEST_TRAINSIZE  = 10000000

${WORKDIR}/config.mk:
	mkdir -p ${dir $@}
	if [ -e ${TRAIN_SRC}.clean.${PRE_SRC}${TRAINSIZE}.gz ]; then \
	  ${MAKE} ${TRAIN_SRC}.clean.${PRE_SRC}${TRAINSIZE}.charfreq \
		  ${TRAIN_TRG}.clean.${PRE_TRG}${TRAINSIZE}.charfreq; \
	  s=`zcat ${TRAIN_SRC}.clean.${PRE_SRC}${TRAINSIZE}.gz | head -10000001 | wc -l`; \
	  S=`cat ${TRAIN_SRC}.clean.${PRE_SRC}${TRAINSIZE}.charfreq | wc -l`; \
	  T=`cat ${TRAIN_TRG}.clean.${PRE_TRG}${TRAINSIZE}.charfreq | wc -l`; \
	else \
	  ${MAKE} ${LOCAL_TRAIN_SRC}; \
	  ${MAKE} ${LOCAL_TRAIN_SRC}.charfreq ${LOCAL_TRAIN_TRG}.charfreq; \
	  s=`head -10000001 ${LOCAL_TRAIN_SRC} | wc -l`; \
	  S=`cat ${LOCAL_TRAIN_SRC}.charfreq | wc -l`; \
	  T=`cat ${LOCAL_TRAIN_TRG}.charfreq | wc -l`; \
	fi; \
	if [ $$s -gt ${LARGEST_TRAINSIZE} ]; then \
	  echo "# ${LANGPAIRSTR} training data bigger than ${LARGEST_TRAINSIZE}" > $@; \
	  echo "GPUJOB_HPC_MEM = 8g"       >> $@; \
	  echo "GPUJOB_SUBMIT  = -multigpu" >> $@; \
	  echo "BPESIZE    = ${BPESIZE}"    >> $@; \
	  echo "DEVSIZE    = ${DEVSIZE}"    >> $@; \
	  echo "TESTSIZE   = ${TESTSIZE}"   >> $@; \
	  echo "DEVMINSIZE = ${DEVMINSIZE}" >> $@; \
	elif [ $$s -gt ${LARGE_TRAINSIZE} ]; then \
	  echo "# ${LANGPAIRSTR} training data bigger than ${LARGE_TRAINSIZE}" > $@; \
	  echo "GPUJOB_HPC_MEM = 8g"       >> $@; \
	  echo "GPUJOB_SUBMIT  = "         >> $@; \
	  echo "MARIAN_VALID_FREQ = 2500"  >> $@; \
	  echo "BPESIZE    = ${BPESIZE}"    >> $@; \
	  echo "DEVSIZE    = ${DEVSIZE}"    >> $@; \
	  echo "TESTSIZE   = ${TESTSIZE}"   >> $@; \
	  echo "DEVMINSIZE = ${DEVMINSIZE}" >> $@; \
	elif [ $$s -gt ${MEDIUM_TRAINSIZE} ]; then \
	  echo "# ${LANGPAIRSTR} training data bigger than ${MEDIUM_TRAINSIZE}" > $@; \
	  echo "GPUJOB_HPC_MEM = 4g"       >> $@; \
	  echo "GPUJOB_SUBMIT  = "         >> $@; \
	  echo "MARIAN_VALID_FREQ = 2500"  >> $@; \
	  echo "MARIAN_WORKSPACE  = 10000" >> $@; \
	  echo "BPESIZE    = 12000"         >> $@; \
	  echo "DEVSIZE    = ${DEVSIZE}"    >> $@; \
	  echo "TESTSIZE   = ${TESTSIZE}"   >> $@; \
	  echo "DEVMINSIZE = ${DEVMINSIZE}" >> $@; \
	elif [ $$s -gt ${SMALL_TRAINSIZE} ]; then \
	  echo "# ${LANGPAIRSTR} training data bigger than ${SMALL_TRAINSIZE}" > $@; \
	  echo "GPUJOB_HPC_MEM = 4g"       >> $@; \
	  echo "GPUJOB_SUBMIT  = "         >> $@; \
	  echo "MARIAN_VALID_FREQ = 1000"  >> $@; \
	  echo "MARIAN_WORKSPACE  = 5000"  >> $@; \
	  echo "MARIAN_VALID_MINI_BATCH = 8" >> $@; \
	  echo "BPESIZE     = 4000"        >> $@; \
	  echo "DEVSIZE     = 1000"        >> $@; \
	  echo "TESTSIZE    = 1000"        >> $@; \
	  echo "DEVMINSIZE  = 250"         >> $@; \
	elif [ $$s -gt ${SMALLEST_TRAINSIZE} ]; then \
	  echo "# ${LANGPAIRSTR} training data less than ${SMALLEST_TRAINSIZE}" > $@; \
	  echo "GPUJOB_HPC_MEM = 4g"       >> $@; \
	  echo "GPUJOB_SUBMIT  = "         >> $@; \
	  echo "MARIAN_VALID_FREQ = 1000"  >> $@; \
	  echo "MARIAN_WORKSPACE  = 3500"  >> $@; \
	  echo "MARIAN_DROPOUT    = 0.5"   >> $@; \
	  echo "MARIAN_VALID_MINI_BATCH = 4" >> $@; \
	  echo "BPESIZE     = 1000"        >> $@; \
	  echo "DEVSIZE     = 500"         >> $@; \
	  echo "TESTSIZE    = 1000"        >> $@; \
	  echo "DEVMINSIZE  = 100"         >> $@; \
	else \
	    echo "${LANGPAIRSTR} too small"; \
	fi; \
	if [ -e $@ ]; then \
	  if [ $$S -gt 1000 ]; then \
	    echo "SRCBPESIZE  = 32000"     >> $@; \
	  fi; \
	  if [ $$T -gt 1000 ]; then \
	    echo "TRGBPESIZE  = 32000"     >> $@; \
	  fi; \
	fi
	echo "SRCLANGS    = ${SRCLANGS}"    >> $@
	echo "TRGLANGS    = ${TRGLANGS}"    >> $@
	echo "SKIPLANGS   = ${SKIPLANGS}"   >> $@
	echo "LANGPAIRSTR = ${LANGPAIRSTR}" >> $@
	echo "DATASET     = ${DATASET}"     >> $@
	echo "TRAINSET    = ${TRAINSET}"    >> $@
	echo "DEVSET      = ${DEVSET}"      >> $@
	echo "TESTSET     = ${TESTSET}"     >> $@
	echo "PRE         = ${PRE}"         >> $@
	echo "SUBWORDS    = ${SUBWORDS}"    >> $@
ifdef SHUFFLE_DATA
	echo "SHUFFLE_DATA      = ${SHUFFLE_DATA}"       >> $@
endif
ifdef FIT_DATA_SIZE
	echo "FIT_DATA_SIZE     = ${FIT_DATA_SIZE}"      >> $@
endif
	echo "MAX_OVER_SAMPLING = ${MAX_OVER_SAMPLING}"  >> $@
	echo "USE_REST_DEVDATA  = ${USE_REST_DEVDATA}"   >> $@
ifdef USE_TARGET_LABELS
	echo "USE_TARGET_LABELS = ${USE_TARGET_LABELS}"  >> $@
endif
