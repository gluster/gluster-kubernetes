# gluster-kubernetes Release and Maintenance Policies

This document outlines the release and maintenance policies of the
gluster-kubernetes project.

## Maintained Branches

The project will only support and actively maintain two branches, `master` and
the latest release branch. The latest release branch will always be reachable
by two HEADs, `<VERSION>-latest` and `stable`. Requests for support of older
branches may be considered on a case-by-case basis, but users will be 
encouraged to use newer versions where possible.

## Version Numbering

This project follows the versioning guidelines outlined by the [Semantic
Versioning specification, version 2.0.0](http://semver.org/spec/v2.0.0.html).
In short, versions numbers will follow the structure `<MAJOR>.<MINOR>.<PATCH>`,
with the following definitions:

 * MAJOR version indicates a fundamental change to the structure of the
   project, often due to innovations from significant changes in the component
   projects. Major versions will typically not be compatible with older
   versions of the component projects.
 * MINOR version indicates a major feature, a broad set of changes, and/or new
   releases of the component projects. Minor versions retain the following
   compatibility guarantees:
   1. Component projects from the last MAJOR release will still work with the
      current code.
   2. Deployments made with the current code will not conflict with other
      deployments made since the last MAJOR release.
 * PATCH version indicates backwards-compatible bug fixes, and guarantees that
   the versions of the component projects has not changed.

## Branch Definitions and Structure

The `master` branch will always contain the latest development code. The
project guarantees that this branch will be functional and tested but not
bug-free. It will always track the latest versions of all component projects
and makes no guarantee of backwards compatibility to older versions of those
projects or itself.

The `stable` branch will track the latest stable release of the code. When a
new release is made, the `stable` branch will be moved to follow the new
release branch.

Each MAJOR and MINOR release will get its own branch, forked from `master`.
Each release branch name will be of the form `<VERSION>-latest`, e.g.
`1.0-latest`. PATCH releases to those versions will be made in those branches,
and will be marked by tags of the form `v<VERSION>`, e.g. `v1.0.0`. PATCH
releases may contain more than one commit, depending on the whimsy of the
release engineers. :)

Commits to a release branch will be of the following types, ranked in order of
preference:

 1. Direct cherry-picks from `master` (`git cherry-pick -sx`)
 2. Cherry-picks from `master` modified to resolve conflicts (change `cherry
    picked from commit` to `based on commit`)
 3. Custom patches

An example git history is presented below.
```
* I (master)
|
* H  * H' (1.1-latest, stable) tag: v1.1.0
|    |
|    * G
|    |
|   /
|  /
| /
|/
* F  * F' (1.0-latest) tag: v.1.0.3
|    |
* E  * E' tag: v1.0.2
|    |
|    * D
|    |
* C  * C' tag: v1.0.1
|    |
|    * B  tag: v1.0.0
|   /
|  /
| /
|/
* A
```
