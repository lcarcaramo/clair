# Tags
> _Built from [`quay.io/ibmz/golang:1.15`](https://quay.io/repository/ibmz/golang?tab=tags)_
-	[`2.0`](https://github.com/lcarcaramo/clair/blob/release-2.0-s390x/Dockerfile) - [![Build Status](https://travis-ci.com/lcarcaramo/clair.svg?branch=release-2.0-s390x)](https://travis-ci.com/lcarcaramo/clair)
# What is Clair

![Clair Logo](https://cloud.githubusercontent.com/assets/343539/21630811/c5081e5c-d202-11e6-92eb-919d5999c77a.png)

Clair is an open source project for the static analysis of vulnerabilities in application containers (currently including [appc] and [docker]).

1. In regular intervals, Clair ingests vulnerability metadata from a configured set of sources and stores it in the database.
2. Clients use the Clair API to index their container images; this parses a list of installed _source packages_ and stores them in the database.
3. Clients use the Clair API to query the database; correlating data is done in real time, rather than a cached result that needs re-scanning.
4. When updates to vulnerability metadata occur, a webhook containg the affected images can be configured to page or block deployments.

Our goal is to enable a more transparent view of the security of container-based infrastructure.
Thus, the project was named `Clair` after the French term which translates to *clear*, *bright*, *transparent*.

[appc]: https://github.com/appc/spec
[docker]: https://github.com/docker/docker/blob/master/image/spec/v1.2.md
[releases]: https://github.com/coreos/clair/releases

## When would I use Clair?

* You've found an image by searching the internet and want to determine if it's safe enough for you to use in production.
* You're regularly deploying into a containerized production environment and want operations to alert or block deployments on insecure software.

## Documentation

* [The CoreOS website] has a rendered version of the latest stable documentation

[The CoreOS website]: https://coreos.com/clair/docs/latest/

# How to use this image

* Start a PostgreSQL database container. _(Clair will need to use this database.)_
```console
$ docker run --name clair-db -p 5432:5432 -e POSTGRES_PASSWORD=<password> -d quay.io/ibmz/postgres:13
```

* Get a copy of the sample `config.yaml` file below and put it in the `/config` directory of a __Docker volume__. _(Fill all `<placeholders>` in `config.yaml`.)_
```yaml
# Copyright 2015 clair authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The values specified here are the default values that Clair uses if no configuration file is specified or if the keys are not defined.
clair:
  database:
    # Database driver
    type: pgsql
    options:
      # PostgreSQL Connection string
      # https://www.postgresql.org/docs/current/static/libpq-connect.html#LIBPQ-CONNSTRING
      source: postgresql://postgres:<password>@<host/ip address>:5432?sslmode=disable

      # Number of elements kept in the cache
      # Values unlikely to change (e.g. namespaces) are cached in order to save prevent needless roundtrips to the database.
      cachesize: 16384

  api:
    # API server port
    port: 6060

    # Health server port
    # This is an unencrypted endpoint useful for load balancers to check to healthiness of the clair server.
    healthport: 6061

    # Deadline before an API request will respond with a 503
    timeout: 900s

    # 32-bit URL-safe base64 key used to encrypt pagination tokens
    # If one is not provided, it will be generated.
    # Multiple clair instances in the same cluster need the same value.
    paginationkey:

    # Optional PKI configuration
    # If you want to easily generate client certificates and CAs, try the following projects:
    # https://github.com/coreos/etcd-ca
    # https://github.com/cloudflare/cfssl
    servername:
    cafile:
    keyfile:
    certfile:

  updater:
    # Frequency the database will be updated with vulnerabilities from the default data sources
    # The value 0 disables the updater entirely.
    interval: 2h

  notifier:
    # Number of attempts before the notification is marked as failed to be sent
    attempts: 3

    # Duration before a failed notification is retried
    renotifyinterval: 2h

    http:
      # Optional endpoint that will receive notifications via POST requests
      endpoint:

      # Optional PKI configuration
      # If you want to easily generate client certificates and CAs, try the following projects:
      # https://github.com/cloudflare/cfssl
      # https://github.com/coreos/etcd-ca
      servername:
      cafile:
      keyfile:
      certfile:

      # Optional HTTP Proxy: must be a valid URL (including the scheme).
      proxy:
```

* Run the Clair image. 
```console
$ docker run --name clair -d -v clair-config-vol:/config -p 6060-6061:6060-6061 quay.io/ibmz/clair:2.0 -config=/config/config.yaml
```

* Perform a health check.
```console
$ curl -X GET -I http://<host/ip where clair container is running>:6061/health
```

* Get an image's vulnerability report. _(Note that you may need to wait several mintues for vulnerabilitiy reports to be ready)_
```console
$ curl -X GET http://<host/ip where clair container is running>:6060/v1/namespaces/debian:10/vulnerabilities?limit=2
```

# Frequently Asked Questions

## Who's using Clair?

You can find [production users] and third party [integrations] documented in their respective pages of the local documentation.

[production users]: https://github.com/coreos/clair/blob/master/Documentation/production-users.md
[integrations]: https://github.com/coreos/clair/blob/master/Documentation/integrations.md

## What do you mean by static analysis?

There are two major ways to perform analysis of programs: [Static Analysis] and [Dynamic Analysis].
Clair has been designed to perform *static analysis*; containers never need to be executed.
Rather, the filesystem of the container image is inspected and *features* are indexed into a database.
By indexing the features of an image into the database, images only need to be rescanned when new *detectors* are added.

[Static Analysis]: https://en.wikipedia.org/wiki/Static_program_analysis
[Dynamic Analysis]: https://en.wikipedia.org/wiki/Dynamic_program_analysis

## What data sources does Clair currently support?

| Data Source                        | Data Collected                                                           | Format | License         |
|------------------------------------|--------------------------------------------------------------------------|--------|-----------------|
| [Debian Security Bug Tracker]      | Debian 6, 7, 8, unstable namespaces                                      | [dpkg] | [Debian]        |
| [Ubuntu CVE Tracker]               | Ubuntu 12.04, 12.10, 13.04, 14.04, 14.10, 15.04, 15.10, 16.04 namespaces | [dpkg] | [GPLv2]         |
| [Red Hat Security Data]            | CentOS 5, 6, 7 namespaces                                                | [rpm]  | [CVRF]          |
| [Oracle Linux Security Data]       | Oracle Linux 5, 6, 7 namespaces                                          | [rpm]  | [CVRF]          |
| [Amazon Linux Security Advisories] | Amazon Linux 2018.03, 2 namespaces                                       | [rpm]  | [MIT-0]         |
| [Alpine SecDB]                     | Alpine 3.3, Alpine 3.4, Alpine 3.5 namespaces                            | [apk]  | [MIT]           |
| [NIST NVD]                         | Generic Vulnerability Metadata                                           | N/A    | [Public Domain] |

[Debian Security Bug Tracker]: https://security-tracker.debian.org/tracker
[Ubuntu CVE Tracker]: https://launchpad.net/ubuntu-cve-tracker
[Red Hat Security Data]: https://www.redhat.com/security/data/metrics
[Oracle Linux Security Data]: https://linux.oracle.com/security/
[Amazon Linux Security Advisories]: https://alas.aws.amazon.com/
[NIST NVD]: https://nvd.nist.gov
[dpkg]: https://en.wikipedia.org/wiki/dpkg
[rpm]: http://www.rpm.org
[Debian]: https://www.debian.org/license
[GPLv2]: https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
[CVRF]: http://www.icasi.org/cvrf-licensing/
[Public Domain]: https://nvd.nist.gov/faq
[Alpine SecDB]: http://git.alpinelinux.org/cgit/alpine-secdb/
[apk]: http://git.alpinelinux.org/cgit/apk-tools/
[MIT]: https://gist.github.com/jzelinskie/6da1e2da728424d88518be2adbd76979
[MIT-0]: https://spdx.org/licenses/MIT-0.html

## What do most deployments look like?

From a high-level, most deployments integrate with the registry workflow rather than manual API usage by a human.
They typically take up a form similar to the following diagram:

![Simple Clair Diagram](https://cloud.githubusercontent.com/assets/343539/21630809/c1adfbd2-d202-11e6-9dfe-9024139d0a28.png)

## I just started up Clair and nothing appears to be working, what's the deal?

During the first run, Clair will bootstrap its database with vulnerability data from the configured data sources.
It can take several minutes before the database has been fully populated, but once this data is stored in the database, subsequent updates will take far less time.

## What terminology do I need to understand to work with Clair internals?

- *Image* - a tarball of the contents of a container
- *Layer* - an *appc* or *Docker* image that may or may not be dependent on another image
- *Feature* - anything that when present could be an indication of a *vulnerability* (e.g. the presence of a file or an installed software package)
- *Feature Namespace* - a context around *features* and *vulnerabilities* (e.g. an operating system)
- *Vulnerability Updater* - a Go package that tracks upstream vulnerability data and imports them into Clair
- *Vulnerability Metadata Appender* - a Go package that tracks upstream vulnerability metadata and appends them into vulnerabilities managed by Clair

## How can I customize Clair?

The major components of Clair are all programmatically extensible in the same way Go's standard [database/sql] package is extensible.
Everything extensible is located in the `ext` directory.

Custom behavior can be accomplished by creating a package that contains a type that implements an interface declared in Clair and registering that interface in [init()].
To expose the new behavior, unqualified imports to the package must be added in your own custom [main.go], which should then start Clair using `Boot(*config.Config)`.

[database/sql]: https://godoc.org/database/sql
[init()]: https://golang.org/doc/effective_go.html#init
[main.go]: https://github.com/coreos/clair/blob/master/cmd/clair/main.go

## Are there any public presentations on Clair?

- _Clair: The Container Image Security Analyzer @ ContainerDays Boston 2016_ - [Event](http://dynamicinfradays.org/events/2016-boston/) [Video](https://www.youtube.com/watch?v=Kri67PtPv6s) [Slides](https://docs.google.com/presentation/d/1ExQGZs-pQ56TpW_ifcUl2l_ml87fpCMY6-wdug87OFU)
- _Identifying Common Vulnerabilities and Exposures in Containers with Clair @ CoreOS Fest 2016_ - [Event](https://coreos.com/fest/) [Video](https://www.youtube.com/watch?v=YDCa51BK2q0) [Slides](https://docs.google.com/presentation/d/1pHSI_5LcjnZzZBPiL1cFTZ4LvhzKtzh86eE010XWNLY)
- _Clair: A Container Image Security Analyzer @  Microservices NYC_ - [Event](https://www.meetup.com/Microservices-NYC/events/230023492/) [Video](https://www.youtube.com/watch?v=ynwKi2yhIX4) [Slides](https://docs.google.com/presentation/d/1ly9wQKQIlI7rlb0JNU1_P-rPDHU4xdRCCM3rxOdjcgc)
- _Clair: A Container Image Security Analyzer @ Container Orchestration NYC_ - [Event](https://www.meetup.com/Container-Orchestration-NYC/events/229779466/) [Video](https://www.youtube.com/watch?v=wTfCOUDNV_M) [Slides](https://docs.google.com/presentation/d/1ly9wQKQIlI7rlb0JNU1_P-rPDHU4xdRCCM3rxOdjcgc)

# License

Apache 2.0 Licence: See details [here](https://github.com/quay/clair/blob/main/LICENSE)
