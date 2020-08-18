
command! -bang -nargs=? -complete=customlist,vsnip#edit#complete VsnipEditSnippet call vsnip#edit#snippet(<q-args>, <bang>0)

