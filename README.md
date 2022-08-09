# LayeredDictionary
A dictionary-like data structure (ie. having all of the behaviour typical of a dictionary or key-value list) for bash where sets of mutations are organized sequentially in "steps" (starting at 0, the initial state, and incrementing when explicitly called for).  This provides an immutable record of mutations made at each step.  It also facilitates rollback of state, the ability to determine when (ie. during which step) a key/value has been set.

Typical use cases for this kind of structure would be keeping state during a deeply-nested workflow of ui dialogs, implementing undo/redo functionality, tracking state in a state-machine-y kind of flow, long-running edits of documents, or generally any time you would want to track mutation of state according to some explicitly user-triggered commit.

This library relies upon Bash's "named-ref" and associative-array functionality.
