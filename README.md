# code-gov-update #

[![GitHub Build Status](https://github.com/cisagov/code-gov-update/workflows/build/badge.svg)](https://github.com/cisagov/code-gov-update/actions/workflows/build.yml)
[![CodeQL](https://github.com/cisagov/code-gov-update/workflows/CodeQL/badge.svg)](https://github.com/cisagov/code-gov-update/actions/workflows/codeql-analysis.yml)
[![Known Vulnerabilities](https://snyk.io/test/github/cisagov/code-gov-update/badge.svg)](https://snyk.io/test/github/cisagov/code-gov-update)

## Docker Image ##

[![Docker Pulls](https://img.shields.io/docker/pulls/cisagov/code-gov-update)](https://hub.docker.com/r/cisagov/code-gov-update)
[![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/cisagov/code-gov-update)](https://hub.docker.com/r/cisagov/code-gov-update)
[![Platforms](https://img.shields.io/badge/platforms-386%20%7C%20amd64%20%7C%20arm%2Fv6%20%7C%20arm%2Fv7%20%7C%20arm64%2Fv8-blue)](https://hub.docker.com/r/cisagov/code-gov-update/tags)

This project contains code for updating the DHS
[code.gov](https://code.gov) inventory published
[here](https://www.dhs.gov/code.json).

## How it works ##

The [LLNL/scraper](https://github.com/LLNL/scraper) project is used to
scrape a handful of GitHub organizations that belong to DHS and
produce an updated JSON file per [the code.gov
specification](https://code.gov/about/compliance/inventory-code).  If
that file differs from the previously-generated one, it is emailed to
the appropriate address so that it can be used to update the content
hosted [here](https://www.dhs.gov/code.json).

## Running ##

### Running with Docker ###

To run the `cisagov/code-gov-update` image via Docker:

```console
docker run cisagov/code-gov-update:0.2.0-rc.1
```

### Running with Docker Compose ###

1. Create a `docker-compose.yml` file similar to the one below to use [Docker Compose](https://docs.docker.com/compose/).

    ```yaml
    ---
    version: '3.7'

    services:
      update:
        image: 'cisagov/code-gov-update:0.2.0-rc.1'
        init: true
        environment:
          - AWS_CONFIG_FILE=path/to/aws_config
          - AWS_PROFILE=default
    ```

1. Start the container and detach:

    ```console
    docker compose up --detach
    ```

## Using secrets with your container ##

This container also supports passing sensitive values via [Docker
secrets](https://docs.docker.com/engine/swarm/secrets/).  Passing sensitive
values like your credentials can be more secure using secrets than using
environment variables.  See the
[secrets](#secrets) section below for a table of all supported secret files.

1. To use secrets, create `aws_config` and `scraper.json` files containing the
   values you want set:

    ```ini
    [default]
    credential_source = Ec2InstanceMetadata
    region = us-east-2
    role_arn = arn:aws:iam::123456789012:role/AssumeSesSendEmail-CodeGovUpdate
    ```

    Please see the [documentation](https://github.com/LLNL/scraper#config-file-options)
    for creating your own `scraper.json` configuration file.

1. Then add the secrets to your `docker-compose.yml` file:

    ```yaml
    ---
    version: '3.7'

    secrets:
      aws_config:
        file: ./src/secrets/aws_config
      scraper_config:
        file: ./src/secrets/scraper.json

    services:
      update:
        image: 'cisagov/code-gov-update:0.2.0-rc.1'
        init: true
        secrets:
          - source: aws_config
            target: aws_config
          - source: scraper_config
            target: scraper_config.json
        environment:
          - AWS_CONFIG_FILE=/run/secrets/aws_config
          - AWS_PROFILE=default
    ```

## Updating your container ##

### Docker Compose ###

1. Pull the new image from Docker Hub:

    ```console
    docker compose pull
    ```

1. Recreate the running container by following the [previous instructions](#running-with-docker-compose):

    ```console
    docker compose up --detach
    ```

### Docker ###

1. Stop the running container:

    ```console
    docker stop <container_id>
    ```

1. Pull the new image:

    ```console
    docker pull cisagov/code-gov-update:0.2.0-rc.1
    ```

1. Recreate and run the container by following the [previous instructions](#running-with-docker).

## Image tags ##

The images of this container are tagged with [semantic
versions](https://semver.org).  It is recommended that most users use a version
tag (e.g. `:0.2.0-rc.1`).

| Image:tag | Description |
|-----------|-------------|
|`cisagov/code-gov-update:0.2.0-rc.1`| An exact release version. |
|`cisagov/code-gov-update:0.1`| The most recent release matching the major and minor version numbers. |
|`cisagov/code-gov-update:0`| The most recent release matching the major version number. |
|`cisagov/code-gov-update:edge` | The most recent image built from a merge into the `develop` branch of this repository. |
|`cisagov/code-gov-update:nightly` | A nightly build of the `develop` branch of this repository. |
|`cisagov/code-gov-update:latest`| The most recent release image pushed to a container registry.  Pulling an image using the `:latest` tag [should be avoided.](https://vsupalov.com/docker-latest-tag/) |

See the [tags tab](https://hub.docker.com/r/cisagov/code-gov-update/tags) on Docker
Hub for a list of all the supported tags.

## Volumes ##

There are no volumes.

<!--
| Mount point | Purpose |
|-------------|---------|
| `/path/to/volume` | Volume description |
-->

## Ports ##

No ports are exposed by this container.

<!--
| Port | Purpose |
|------|---------|
| `PORT_NUMBER` | Describe its purpose. |
-->

## Environment variables ##

### Required ###

There are no required environment variables.

<!--
| Name | Purpose | Default |
|------|---------|---------|
| `REQUIRED_VARIABLE` | Describe its purpose. | `null` |
-->

### Optional ###

There are no optional environment variables.

<!--
| Name | Purpose | Default |
|------|---------|---------|
| `OPTIONAL_VARIABLE` | Describe its purpose. | `null` |
-->

## Secrets ##

| Filename | Purpose |
|----------|---------|
| `aws_config` | Provides the necessary AWS authentication to send email using SES. |
| `scraper.json` | Provides the configuration to use for LLNL/scraper.

## Building from source ##

Build the image locally using this git repository as the [build context](https://docs.docker.com/engine/reference/commandline/build/#git-repositories):

```console
docker build \
  --tag cisagov/code-gov-update:0.2.0-rc.1 \
  https://github.com/cisagov/code-gov-update.git#develop
```

## Cross-platform builds ##

To create images that are compatible with other platforms, you can use the
[`buildx`](https://docs.docker.com/buildx/working-with-buildx/) feature of
Docker:

1. Copy the project to your machine using the `Code` button above
   or the command line:

    ```console
    git clone https://github.com/cisagov/code-gov-update.git
    cd code-gov-update
    ```

1. Create the `Dockerfile-x` file with `buildx` platform support:

    ```console
    ./buildx-dockerfile.sh
    ```

1. Build the image using `buildx`:

    ```console
    docker buildx build \
      --file Dockerfile-x \
      --platform linux/amd64 \
      --output type=docker \
      --tag cisagov/code-gov-update:0.2.0-rc.1 .
    ```

## Contributing ##

We welcome contributions!  Please see [`CONTRIBUTING.md`](CONTRIBUTING.md) for
details.

## License ##

This project is in the worldwide [public domain](LICENSE).

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.
