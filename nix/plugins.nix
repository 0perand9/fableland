# The ways a plugin can be named, in `programs.fableland.plugins` and in the
# package's `plugins` argument, made into { src, runtimeInputs }:
#
#   "hello"                                       a plugin in Fableland's plugins/
#   ./my-plugin   inputs.fable-thing   a package   a plugin's folder
#   { github = "owner/repo"; rev = "…"; hash = "sha256-…"; }
#                                                 fetched from GitHub, pinned by its hash
#   { src = …; dir = "plugins/x"; runtimeInputs = [ pkgs.jq ]; }
#                                                 any of the above with a subfolder, or
#                                                 with programs the plugin runs (put on
#                                                 fable's PATH)
#
# `github` takes `dir` and `runtimeInputs` too.
{ lib, fetchFromGitHub }:

let
  inFolder = dir: src: if dir == null then src else "${src}/${dir}";

  resolve =
    entry:
    if lib.isString entry || lib.isPath entry || lib.isDerivation entry || (lib.isAttrs entry && entry ? outPath) then
      {
        src = entry;
        runtimeInputs = [ ];
      }
    else if lib.isAttrs entry && entry ? github then
      let
        parts = lib.splitString "/" entry.github;
      in
      assert lib.assertMsg (lib.length parts == 2) "fableland plugin: github = \"owner/repo\", not \"${entry.github}\"";
      {
        src = inFolder (entry.dir or null) (fetchFromGitHub {
          owner = lib.elemAt parts 0;
          repo = lib.elemAt parts 1;
          inherit (entry) rev hash;
        });
        runtimeInputs = entry.runtimeInputs or [ ];
      }
    else if lib.isAttrs entry && entry ? src then
      {
        src = inFolder (entry.dir or null) entry.src;
        runtimeInputs = entry.runtimeInputs or [ ];
      }
    else
      throw "fableland plugin: expected a name, a folder, { github, rev, hash } or { src }";
in
map resolve
