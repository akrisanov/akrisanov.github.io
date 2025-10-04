+++
title = "Identifying Vulnerable Dependencies In .NET Projects"
description = "How to scan NuGet packages for security vulnerabilities using GitLab CI."
date = 2024-05-07
draft = false

[taxonomies]
tags = [".NET", "NuGet", "DevOpsSec", "GitLab CI"]

[extra]
keywords = ".NET, NuGet, DevOpsSec, supply chain attacks, GitLab CI"
toc = false
+++

Some time ago, I was working in a company that was building a SaaS that was written in .NET.
The code base was a decade old, and like many companies using Microsoft technologies,
it had been through a few framework upgrades. The intent was to move to modern technologies and
refactor outdated components, but the execution was rather poor. By the time I put on my engineering
manager's hat, many of the NuGet packages in the solution were out of date and even deprecated.

In Python and Go projects, I rely heavily on linting, static analysis, and formatting tools.
Not having these essentials would make me and my teams less productive. So the first thing I did
was understand what modern .NET brings to the table in this area. And I started by scanning the
NuGet packages we use in all of our projects in a single solution for potential vulnerabilities.

It turned out that developers could simply run `dotnet list package --vulnerable` locally
to keep an eye on security. But without automation, it's too easy to forget about that.

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

As you can see, there are several projects vulnerable to [CVE-2022-41064](https://devhub.checkmarx.com/cve-details/CVE-2022-41064/).

> .NET Framework System.Data.SqlClient versions prior to 4.8.5 and Microsoft.Data.SqlClient
> versions prior to 1.1.4 and 2.0.0 prior to 2.1.2 is vulnerable to Information Disclosure Vulnerability.

To get rid of the issue, it's enough to upgrade the package:

```bash
dotnet add package System.Data.SqlClient -v 4.8.6
```

Now, how can developers prevent such situations? You already know the answer: automation!

After sharing my observations with the team, I created a merge request with a new GitLab pipeline
that runs for every open merge request and master branch.

These are the changes in the `.gitlab-ci.yml` manifest:

```yaml
stages:
  - security

vulnarable-dependencies:
  stage: security
  image: mcr.microsoft.com/dotnet/sdk:6.0-bullseye-slim
  before_script:
    - dotnet restore
  script:
    - dotnet list package --vulnerable 2>&1 | tee vulnerable-packages.log
    - >-
      ! grep -qiw "critical\|high\|moderate\|low" vulnerable-packages.log;
      if [ $? -ne 0 ]; then
        echo "🚨 Found vulnarable packages";
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

The pipeline will fail if any of the projects in the solution have vulnerable packages.
The downloadable log file contains the list of vulnerabilities and their severity.

This way, the team is always aware of the state of the dependencies and can take action to fix them.

References:

- [How to Scan NuGet Packages for Security Vulnerabilities](https://devblogs.microsoft.com/nuget/how-to-scan-nuget-packages-for-security-vulnerabilities/)
