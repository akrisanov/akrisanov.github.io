+++
title = "Synchronizing Users From LDAP With Keycloak Using AD Filters"
description = "Keycloak allows configuring a custom LDAP user filter for User Federation to select a subset of user entries in Active Directory."
date = 2023-09-23
draft = false

[taxonomies]
tags = ["keycloak"]

[extra]
keywords = "keycloak, ldap, active-directory"
toc = false
+++

One of the ways to synchronize users via a third-party provider with Keycloak is a mechanism
called User Federation. It allows, using Kerberos or LDAP protocol, to pull user entries from your
corporate authentication storage. However, if your organization is big enough to have a complex
structure and there are a lot of users in the user directory, it could be challenging to get only
a subset of the accounts that belong to different organization units.

For example, Active Directory models a tree-based structure using the following entities:

- `CN` = Common Name
- `OU` = Organizational Unit
- `DC` = Domain Component

All the distinguished names can be found in [the official documentation](https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ldap/distinguished-names)
provided by Microsoft.

To configure a new User Federation in Keycloak, it's required to specify a User DN.
This distinguished name is the base object in the directory information tree where the search
begins forming candidates for pulling authentication entries. Therefore, we need to know how to
construct the User DN.

The base option that an Active Directory administrator could use to create user accounts is to
organize them under organizational units:

```
OU=Main,DC=Orgname,DC=ru
```

Even if your organizational unit has a complex structure, it's still relatively easy for Keycloak
to find user entries inside it – just activate the `Search Scope: Subtree` setting when configuring
the user federation. In large organizations, the Active Directory structure can get quite messy.
Instead of using clear distinguished names, administrators do something surprising even to them.
How about putting entries under CN in different organizational units?

This is what I encountered while working on corporate user authentication for a media platform's CMS.
User entries of the editors were grouped via the Common Name. So, there is no way to define User DN
in the way I've mentioned in the example above. Fortunately, the LDAP connection allows providing
a filter for Active Directory. In my case, writing the filter to select all of the members of the
`CMS_EDITOR` group was enough to solve a problem:

```
(&(objectCategory=Person)(sAMAccountName=*)(|(memberOf=CN=CMS_EDITOR,OU=Security,OU=Groups,OU=Central,OU=Main,DC=Orgname,DC=ru)))
```

Moreover, the `Custom User LDAP Filter` setting in Keycloak supports logical operators like _or_
with `|`, and I could use it for finding not only the members of the editor staff but also
CMS admins, guests, etc.
