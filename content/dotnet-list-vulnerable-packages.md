+++
title = "Identifying Vulnerable Dependencies in .NET Projects"
description = "Scan .NET dependencies for known NuGet vulnerabilities and fail GitLab CI when vulnerable packages are found."
date = 2024-05-07
draft = false

[taxonomies]
tags = ["dotnet", "nuget", "dependency-scanning", "supply-chain-security", "gitlab-ci"]

[extra]
keywords = "dotnet, nuget, dependency-scanning, supply-chain-security, gitlab-ci"
toc = false
static_thumbnail = "/images/social-dotnet-list-vulnerable-packages.png"

+++

At a previous company, I worked on a decade-old .NET SaaS codebase that had been through several framework upgrades.
The upgrades were incomplete, and many NuGet packages in the solution were outdated or deprecated by the time I
became the engineering manager.

I rely on linting, static analysis, and formatting tools in Python and Go projects, so I reviewed the equivalent
tooling available for .NET. I started by scanning every NuGet package in the solution for known vulnerabilities.

The .NET CLI provides this check through `dotnet list package --vulnerable`. Developers can run it locally, but an
automated check prevents it from being missed.

<!-- more -->

## Scan Packages Locally

My first local scan produced the following result:

```bash
...
Project `X.Infrastructure.Calendar` has the following vulnerable packages
   [net6.0]:
   Top-level Package            Requested   Resolved   Severity   Advisory URL
   > System.Data.SqlClient      4.8.3       4.8.3      Moderate   https://github.com/advisories/GHSA-8g2p-5pqh-5jmc
                                                       High       https://github.com/advisories/GHSA-98g6-xh36-x2p7

The given project `X.Infrastructure.Common` has no vulnerable packages given the current sources.
Project `X.Infrastructure.Currency` has the following vulnerable packages
   [net6.0]:
   Top-level Package            Requested   Resolved   Severity   Advisory URL
   > System.Data.SqlClient      4.8.3       4.8.3      Moderate   https://github.com/advisories/GHSA-8g2p-5pqh-5jmc
                                                       High       https://github.com/advisories/GHSA-98g6-xh36-x2p7

Project `X.Infrastructure.Locker` has the following vulnerable packages
   [net6.0]:
   Top-level Package            Requested   Resolved   Severity   Advisory URL
   > System.Data.SqlClient      4.8.3       4.8.3      Moderate   https://github.com/advisories/GHSA-8g2p-5pqh-5jmc
                                                       High       https://github.com/advisories/GHSA-98g6-xh36-x2p7

The given project `X.Infrastructure.Locker.Tests.Unit` has no vulnerable packages given the current sources.
The given project `X.Infrastructure.Pool` has no vulnerable packages given the current sources.
Project `X.Infrastructure.Repositories` has the following vulnerable packages
   [net6.0]:
   Top-level Package            Requested   Resolved   Severity   Advisory URL
   > System.Data.SqlClient      4.8.3       4.8.3      Moderate   https://github.com/advisories/GHSA-8g2p-5pqh-5jmc
                                                       High       https://github.com/advisories/GHSA-98g6-xh36-x2p7

The given project `X.Infrastructure.Rules` has no vulnerable packages given the current sources.
...
```

Several projects use a version of `System.Data.SqlClient` affected by
[CVE-2022-41064](https://devhub.checkmarx.com/cve-details/CVE-2022-41064/):

> .NET Framework System.Data.SqlClient versions prior to 4.8.5 and Microsoft.Data.SqlClient
> versions prior to 1.1.4 and 2.0.0 prior to 2.1.2 is vulnerable to Information Disclosure Vulnerability.

Upgrade the package to resolve the vulnerability:

```bash
dotnet add package System.Data.SqlClient -v 4.8.6
```

## Run the Check in GitLab CI

I added a GitLab pipeline that runs for merge requests and the `master` branch.

The `.gitlab-ci.yml` configuration is:

```yaml
stages:
  - security

vulnerable-dependencies:
  stage: security
  image: mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim
  before_script:
    - dotnet restore
  script:
    - dotnet list package --vulnerable 2>&1 | tee vulnerable-packages.log
    - >-
      ! grep -qiw "critical\|high\|moderate\|low" vulnerable-packages.log;
      if [ $? -ne 0 ]; then
        echo "🚨 Found vulnerable packages";
        exit 1
      else
        exit 0
      fi
  artifacts:
    when: always
    expire_in: 12h
    paths:
      - vulnerable-packages.log
  only:
    - master
    - merge_requests
  tags:
    - docker
```

The pipeline fails if any project in the solution has a vulnerable package. It stores the command output as a
downloadable artifact, including each vulnerability and its severity.

## Reference

- [How to Scan NuGet Packages for Security Vulnerabilities](https://devblogs.microsoft.com/nuget/how-to-scan-nuget-packages-for-security-vulnerabilities/)
