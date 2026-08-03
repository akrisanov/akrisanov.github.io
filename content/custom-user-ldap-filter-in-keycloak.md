+++
title = "Synchronize Active Directory Users with a Keycloak LDAP Filter"
description = "Configure Keycloak User Federation with a custom LDAP filter to synchronize selected Active Directory users."
date = 2023-09-23
draft = false

[taxonomies]
tags = ["keycloak", "ldap", "active-directory", "identity-access-management"]

[extra]
keywords = "keycloak, ldap, active-directory, identity-access-management"
toc = false
static_thumbnail = "/images/social-custom-user-ldap-filter-in-keycloak.png"

+++

Keycloak User Federation can synchronize users from an external directory through LDAP or Kerberos. In a large
Active Directory structure, the users required by one Keycloak realm may be spread across several organizational
units. A custom LDAP filter can select only those accounts.

<!-- more -->

Active Directory distinguished names use components such as:

- `CN` = Common Name
- `OU` = Organizational Unit
- `DC` = Domain Component

Microsoft's [distinguished names documentation](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ldap/distinguished-names)
describes these components and their syntax.

Keycloak requires a User DN when configuring an LDAP user federation. This value identifies the base object in the
directory tree where Keycloak starts searching for users.

For users stored under one organizational unit, the User DN can be:

```text
OU=Main,DC=Orgname,DC=ru
```

Set `Search Scope` to `Subtree` to include users in nested organizational units below this DN.

While configuring corporate authentication for a media platform's CMS, I needed accounts that were stored in
different parts of the directory but belonged to the `CMS_EDITOR` group. A single organizational unit could not
select them, so I added this value to Keycloak's `Custom User LDAP Filter` setting:

```text
(&(objectCategory=Person)(sAMAccountName=*)(|(memberOf=CN=CMS_EDITOR,OU=Security,OU=Groups,OU=Central,OU=Main,DC=Orgname,DC=ru)))
```

The filter selects person objects with a `sAMAccountName` that belong to `CMS_EDITOR`. The `|` operator is a logical
OR. Add more `memberOf` expressions inside it to include groups such as CMS administrators or guests.
