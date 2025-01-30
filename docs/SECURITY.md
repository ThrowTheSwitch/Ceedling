# Security Policies and Procedures

This document outlines security procedures and general policies for all `ThrowTheSwitch.org`
projects, including `Unity`, `CMock`, and `Ceedling`.

  * [Reporting a Bug](#reporting-a-bug)
  * [Disclosure Policy](#disclosure-policy)
  * [Comments on this Policy](#comments-on-this-policy)

## Reporting a Bug

The tools from `ThrowTheSwitch.org` are made to collaborate with other tools like compilers, 
simulators, and such, and therefore have very low-level access to the world they live in. 
However, they are typically used in controlled development-centered environments. As such, 
they are typically not directly exposed to security concerns. 

The `ThrowTheSwitch.org` community takes security bugs seriously. Where possible, we will
make every effort to improve our tools safe use. Thank you for improving the security of 
our tools. We appreciate your efforts and responsible disclosure and will make every effort 
to acknowledge your contributions.

Report security bugs by opening a Github Issue on the corresponding project or (when this
itself would pose a risk) by emailing security@thingamabyte.com.

Report security bugs in third-party modules to the person or team maintaining
the module.

## Disclosure Policy

Each issue will be assigned to a primary handler. This person will coordinate the fix and 
release process, involving the following steps:

  * Confirm the problem and determine the affected versions.
  * Audit code to find any potential similar problems.
  * Prepare fixes for all releases still under maintenance. These fixes will be
    released as fast as possible.

## Comments on this Policy

If you have suggestions on how this process could be improved please submit a
pull request.
