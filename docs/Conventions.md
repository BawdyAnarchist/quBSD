
# Documenting the conventions for the code

---

## Variables

CAPS: Critical globals from 1) constants.sh ; 2) cell PARAMETERS expect to live through a script lifecycle ; or 3) parse_args level key globals for the lifecycle of an exec or qb script.
\_CAPS: The execution commands intended for system mutation at the end of a script lifecycle. These should always wrap if necessary, as otherwise `DRY_RUN` and `VERBOSE` console printing becomes cumbersome
lower: Lesser global variables assigned in the process of an exec or qb script.
\_lower: Always local to a function.

Library functions are generally all snake\_case. Functions which serve as helpers for only one function (for cleaner modularization) should be proceeded with an underscore: `_lib_helper_func()`. Only the exception system of: THROW, WARN, PASS, MUTE, and CLEAR receive CAPS SNAKE\_CASE, due to both their unique nature as flow interruption, and MACROS. 

### Passing context PARAMETERS into library functions
The eval-based context.sh system can bootstraps multiple cells in the same script without clobber. It's also convenient to avoid prop-drilling.
1. Lib functions may direcly use PARAMETERS, but they should always come included with `_pfx=$1`
2. Define local-vars at the top with example:  `_rootenv=$(ctx_get ${_pfx}ROOTENV)`
3. If you must bootstrap new params, use a unique lowercase prefix: `ctx_bootstrap_cell $_rootenv rcc_`
4. These bootstrapped contexts are considered dispensable and clobber-able
5. Even so best practice is to unset that prefix at the end of the function (not always necessary)
6. Be wary of calling these kinds of function to the background in parallel. Consider exec if necessary.

## Script flow
The general idea is to push actual system mutations until the very last moment. This is common for a complex architecture. The script flow should usually look like:
Bootstrap => Validate => Resolution/Derivation => Compose Commands => Write Context => Execute

This is by no means a "hard" requirement. Don't be rigid. Context may be written early in some cases or late in others, but the general idea is: Prepare => Execute.

Execution was designed explicitly for `exec_cmd "$1"`. Obviously you must use quotes around the command. There are two very useful options: `DRY_RUN` and `VERBOSE` passed as env variables ahead of time. This either prints the commands to be run without execution; or prints each command the moment before execution.

## THROW and TRACE systems
These are clever, but safe, powerful, and easy to use. They're also an innovation, enabling straightforward exception policy rarely/ever seen in shell scripts, much less POSIXy scripts. Due to its special nature of interrupting code flow, it should be placed in CAPS. Same for WARN.

It always takes the form of:
` || eval $(THROW _code message_type "$data" $data2" ...)`
` || eval $(THROW 1 _generic "Failed to write runtime context")`

It depends on the user to "percolate" up critical failures/flows. The primitives were largely constructed carefully with THROW, but it's up to the dev to ensure the `resolve_`, `compose_`, (etc), functions they write, insert the THROW syntax at the right places to percolate up to main.

Main must always take this form:
`main || { cat $ERR ; exit 1 ;}`

THROW is inherently safe by enforcing that the provided return code is a positive integer. Thus, you can't accidentally push a dangerous command to the ` || eval ` portion (which you might've intended as `message_type`)

$ERR is a constants.sh global for each script invocation, where both THROW and WARN dump messages. When TRACE is enabled, it also dumps the variable: `$_fn`. Thus, all functions (even ones without throw) ALWAYS get `_fn=func_name`, as a matter of convention. The visual separation is also nice, AND, it's the correct spot to define the `_local_vars` that are used, on the same line.

CLEAR is occassionally needed when a WARN is discarded in favor of some alternative path, to not pollute the $ERR file

MUTE is rarely used, if/when you know that some error is harmless and you want clean up the $ERR file regardless.

## Library Notes

query.sh - Seeks to THROW only on missing args. This is primitives level protection against higher level mistakes.
assert.sh - Doesnt need to THROW on missing args, the syntax IS the requirement. 
validate.sh - Almost entirely references query.sh and assert.sh; plus some additional logic where necessary.
*In combination, these primitives provide broad protection in the face of missing args, and invalid user inputs, and helps avoid repeated verifications. That doesn't mean you should never issue additional safety checks, it just means, be mindful of loop costs, and whether or not a previous validation has you covered already.*



