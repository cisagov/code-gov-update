# code-gov-update #

[![Build Status](https://travis-ci.com/cisagov/code-gov-update.svg?branch=develop)](https://travis-ci.com/cisagov/code-gov-update)
[![Total alerts](https://img.shields.io/lgtm/alerts/g/cisagov/code-gov-update.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/cisagov/code-gov-update/alerts/)
[![Language grade: Python](https://img.shields.io/lgtm/grade/python/g/cisagov/code-gov-update.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/cisagov/code-gov-update/context:python)

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

## Contributing ##

We welcome contributions!  Please see [here](CONTRIBUTING.md) for
details.

## License ##

This project is in the worldwide [public domain](LICENSE.md).

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the [CC0 1.0 Universal public domain
dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.
