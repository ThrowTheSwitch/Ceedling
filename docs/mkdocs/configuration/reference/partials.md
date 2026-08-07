# `:partials`

**Configuring C feature extraction for Partials**

## Example `:partials` YAML

```yaml
:partials:
  :max_extraction_length: 8000
```

## `:max_extraction_length`

Building a Partial requires Ceedling to extract each C construct — a
variable declaration, a function, a macro, and so on — from your source
files one at a time. Extraction reads a construct into a growing buffer
until it finds that construct's natural end (a terminating `;`, a closing
`}`, etc.). This setting bounds how large that buffer may grow before
extraction fails outright, rather than continuing to search indefinitely
into whatever else follows in the file.

The value is a multiplier of 1000 characters, not a raw character count —
`8000` means 8,000,000 characters. It must be a whole number no smaller
than `10` (10,000 characters).

Raise this value if Ceedling reports an extraction failure for a
legitimately large single construct in your codebase — a sizable generated
lookup table, for instance. There's ordinarily no reason to lower it.

**Default**: 5000 (5,000,000 characters)

<br/><br/>
