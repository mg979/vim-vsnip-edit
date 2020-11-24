Add-on for https://github.com/hrsh7th/vim-vsnip

### Usage

    VsnipEditSnippet[!] [snippet]

Edit `snippet` or create a new one. `bang` will only consider filetype-specific
snippets.

The snippet is edited in a temporary buffer, than saved back to the snippet file with `:w`.

A system python installation is needed (to reformat the snippets file).

These mappings can be used in the temporary buffer:
```
imap <C-x><C-u>     user completion for $TM_variables
imap $              expands to ${|}
xmap $              encloses selection in ${}
```
