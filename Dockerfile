FROM python:3.10.5-alpine3.16

###
# For a list of pre-defined annotation keys and value types see:
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#
# Note: Additional labels are added by the build workflow.
###
LABEL org.opencontainers.image.authors="vm-fusion-dev-group@trio.dhs.gov"
LABEL org.opencontainers.image.vendor="Cybersecurity and Infrastructure Security Agency"

# Dependencies necessary to build cryptography
# These are required to build the package if a pre-built wheel is not
# available on PyPI.
ENV CRYPTOGRAPHY_BUILD_DEPS \
  cargo \
  gcc \
  libffi-dev \
  musl-dev \
  openssl-dev \
  python3-dev

# Dependencies for the LLNL/scraper Python package
# These are used to estimate labor hours for code.
ENV SCRAPER_DEPS \
  cloc \
  git

###
# Unprivileged user setup variables
###
ARG CISA_UID=421
ARG CISA_GID=${CISA_UID}
ARG CISA_USER="cisa"
ENV CISA_GROUP=${CISA_USER}
ENV CISA_HOME="/home/${CISA_USER}"

###
# Create unprivileged user
###
RUN addgroup --system --gid ${CISA_GID} ${CISA_GROUP} \
  && adduser --system --uid ${CISA_UID} --ingroup ${CISA_GROUP} ${CISA_USER}

##
# Install cloc and git since llnl-scraper requires them to estimate
# the labor hours.
##
RUN apk --no-cache add \
  $CRYPTOGRAPHY_BUILD_DEPS \
  $SCRAPER_DEPS

##
# Make sure pip and setuptools are the latest versions
##
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

##
# Install code-gov-update python requirements
##
COPY src/requirements.txt /tmp
RUN python -m pip install --no-cache-dir --upgrade --requirement /tmp/requirements.txt

# Put this just before we change users because the copy (and every
# step after it) will often be rerun by docker, but we need to be root
# for the chown command.
COPY src/update.sh src/email-update.py src/body.txt src/body.html $CISA_HOME/
RUN chown -R ${CISA_USER}:${CISA_USER} $CISA_HOME

###
# Prepare to run
###
WORKDIR ${CISA_HOME}
USER ${CISA_USER}
ENTRYPOINT ["./update.sh"]
