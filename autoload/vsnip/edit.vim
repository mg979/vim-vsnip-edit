""
" vsnip#edit#complete
""
fun! vsnip#edit#complete(A, L, P) abort
  let bang = a:L =~ '^VsnipEditSnippet!'
  let paths = filter(vsnip#source#user_snippet#paths(), 'filereadable(v:val)')
  if bang
    call filter(paths, 'v:val !~ "global.json"')
  endif
  let snippets = []
  for p in paths
    let json = json_decode(readfile(p))
    let snippets = snippets + keys(json)
  endfor
  return filter(sort(snippets), 'v:val=~#a:A')
endfun

""
" vsnip#source#edit#snippet
""
fun! vsnip#edit#snippet(name, bang) abort
  if executable('python')
    let s:pretty_print = '%!python -m json.tool'
  elseif executable('python3')
    let s:pretty_print = '%!python3 -m json.tool'
  else
    echo '[vsnip] no python executable found in $PATH'
    return
  endif

  let create_new_file = 0

  let paths = filter(vsnip#source#user_snippet#paths(), 'filereadable(v:val)')
  if a:bang
    call filter(paths, 'v:val !~ "global.json"')
  endif

  if empty(paths)
    echo '[vsnip] no valid snippets json files found'
    if !s:create_new_file(a:bang)
      return
    else
      let create_new_file = 1
    endif
  endif

  let s:name = a:name == '' ? input('Enter snippet name: ') : a:name
  if s:name !~ '^\p\+$'
    echo '[vsnip] invalid name'
    return
  endif

  if !create_new_file
    let s:json_path = s:get_path(paths)
    if !filereadable(s:json_path)
      redraw
      echo '[vsnip] invalid path'
      return
    endif
  endif

  let s:snippets = json_decode(readfile(s:json_path))
  call s:temp_buffer(&filetype)
endfun

""
" s:create_new_file
""
fun! s:create_new_file(bang)
  if confirm('Do you want to create a snippet file at `' . g:vsnip_snippet_dir . '`?', "&Yes\n&No") == 1
    let [type, ft, global] = ['', &filetype, 'global']
    if a:bang
      let type = ft
    else
      let ix = inputlist(['Select type: '] + map([ft, global], { k,v -> printf('%s: %s', k + 1, v) }))
      if ix && ix <= 2
        let type = [ft, global][ix - 1]
      endif
    endif
    if type == ''
      return v:false
    else
      if !isdirectory(g:vsnip_snippet_dir)
        if confirm('Create directory `' .g:vsnip_snippet_dir . '`?' , "&Yes\n&No") == 1
          call mkdir(expand(g:vsnip_snippet_dir), 'p')
        else
          return v:false
        endif
      endif
      let s:json_path = expand(g:vsnip_snippet_dir) . '/' . type . '.json'
      call writefile(['{}'], s:json_path)
      return v:true
    endif
  else
    return v:false
  endif
endfun

""
" s:get_path
""
fun! s:get_path(paths) abort
  if len(a:paths) > 1
    let choices = map(copy(a:paths), { k, v -> printf('%s: %s', k + 1, v) })
    let idx = inputlist(['Select snippet file: '] + choices)
  else
    let idx = 1
  endif
  if !idx
    return v:null
  else
    return a:paths[idx - 1]
  endif
endfun

""
" s:temp_buffer
""
fun! s:temp_buffer(ft) abort
  keepalt new! Vsnip\ snippet
  exe 'setf' a:ft
  setlocal noexpandtab
  setlocal list
  setlocal buftype=acwrite
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nobuflisted
  if has_key(s:snippets, s:name)
    call setline(1, s:snippets[s:name]['body'])
  endif
  call matchadd('PreProc', '\${.\{-}\%(:.\{-}\)\?}')
  call matchadd('PreProc', '\$[A-Z0-9_]\+')
  call matchadd('String', '\${.\{-}\zs:.\{-}\ze}')
  call matchadd('NonText', '\s\+')
  setlocal nomodified
  let &l:statusline = ' Editing snippet: %#CursorLine#  ' . s:name . '%=%#WarningMsg# (:w to save snippet) '
  autocmd BufWriteCmd <buffer> call s:save_snippet()
  inoremap <buffer> <C-V> <C-X><C-U>
  setlocal completefunc=vsnip#edit#variable
  inoremap <buffer><expr> $ matchstr(getline('.'),'\%'.(col('.')-1).'c.')=='\'?'$':"${}\<C-G>U\<Left>"
endfun

""
" s:save_snippet
""
fun! s:save_snippet() abort
  retab!
  let lines = getline(1, line('$'))
  bwipeout!
  exe 'topleft vsplit' fnameescape(s:json_path)
  setf json
  if has_key(s:snippets, s:name)
    let s:snippets[s:name]['body'] = lines
    call s:update_snipptes_file()
  else
    call s:save_new_snippet(lines)
  endif
endfun

""
" s:update_snipptes_file
""
fun! s:update_snipptes_file() abort
  silent %d _
  put =json_encode(s:snippets)
  silent 1d _
  exe s:pretty_print
  setlocal noexpandtab tabstop=4 softtabstop=4 shiftwidth=4
  retab!
  update
  call vsnip#source#refresh(fnamemodify(bufname('%'), ':p'))
  let name = escape(s:name, '\"')
  call search('^\V\s\*"' . escape(name, '\') . '":')
endfun

""
" s:save_new_snippet
""
fun! s:save_new_snippet(lines) abort
  redraw
  let snip = {'body': a:lines}

  let desc = input('Enter a description: ')
  if desc !~ '^\p\+$'
    redraw
    echo '[vsnip] using' s:name 'as description'
    let desc = s:name
  endif
  let prefix = input('Enter a prefix (no spaces): ')
  if prefix !~ '^\p\+$'
    redraw
    let prefix = split(s:name)[0]
    echo '[vsnip] using' prefix 'as prefix'
  else
    let prefix = split(prefix)[0]
  endif

  let snip.description = desc
  let snip.prefix = [prefix]
  let s:snippets[s:name] = snip
  call s:update_snipptes_file()
endfun


""
" Variable completion
""
let s:variables = [
      \ {'word': 'TM_SELECTED_TEXT',         'kind': "\tThe currently selected text or the empty string"},
      \ {'word': 'TM_CURRENT_LINE',          'kind': "\tThe contents of the current line"},
      \ {'word': 'TM_CURRENT_WORD',          'kind': "\tThe contents of the word under cursor or the empty string"},
      \ {'word': 'TM_LINE_INDEX',            'kind': "\tThe zero-index based line number"},
      \ {'word': 'TM_LINE_NUMBER',           'kind': "\tThe one-index based line number"},
      \ {'word': 'TM_FILENAME',              'kind': "\tThe filename of the current document"},
      \ {'word': 'TM_FILENAME_BASE',         'kind': "\tThe filename of the current document without its extensions"},
      \ {'word': 'TM_DIRECTORY',             'kind': "\tThe directory of the current document"},
      \ {'word': 'TM_FILEPATH',              'kind': "\tThe full file path of the current document"},
      \ {'word': 'CLIPBOARD',                'kind': "\tThe contents of your clipboard"},
      \ {'word': 'WORKSPACE_NAME',           'kind': "\tThe name of the opened workspace or folder"},
      \ {'word': 'CURRENT_YEAR',             'kind': "\tThe current year"},
      \ {'word': 'CURRENT_YEAR_SHORT',       'kind': "\tThe current year's last two digits"},
      \ {'word': 'CURRENT_MONTH',            'kind': "\tThe month as two digits (example '02')"},
      \ {'word': 'CURRENT_MONTH_NAME',       'kind': "\tThe full name of the month (example 'July')"},
      \ {'word': 'CURRENT_MONTH_NAME_SHORT', 'kind': "\tThe short name of the month (example 'Jul')"},
      \ {'word': 'CURRENT_DATE',             'kind': "\tThe day of the month"},
      \ {'word': 'CURRENT_DAY_NAME',         'kind': "\tThe name of day (example 'Monday')"},
      \ {'word': 'CURRENT_DAY_NAME_SHORT',   'kind': "\tThe short name of the day (example 'Mon')"},
      \ {'word': 'CURRENT_HOUR',             'kind': "\tThe current hour in 24-hour clock format"},
      \ {'word': 'CURRENT_MINUTE',           'kind': "\tThe current minute"},
      \ {'word': 'CURRENT_SECOND',           'kind': "\tThe current second"},
      \ {'word': 'CURRENT_SECONDS_UNIX',     'kind': "\tThe number of seconds since the Unix epoch"},
      \ {'word': 'BLOCK_COMMENT_START',      'kind': "\tExample output: in PHP /* or in HTML <!--"},
      \ {'word': 'BLOCK_COMMENT_END',        'kind': "\tExample output: in PHP */ or in HTML -->"},
      \ {'word': 'LINE_COMMENT',             'kind': "\tExample output: in PHP //"},
      \]

""
" vsnip#edit#variable: completefunc method for built-in variables
""
fun! vsnip#edit#variable(findstart, base) abort
  if a:findstart
    " locate the start of the word
    let beforeCur = getline('.')[:(getcurpos()[2]-2)]
    return match(beforeCur, '\k\k\+$')
  else
    " find match
    if empty(a:base)
      return []
    endif
    let fuzzy = join(split(a:base, '\zs'), '\.\{-}')
    let words = filter(copy(s:variables), { k,v -> v.word =~ '^\V' . fuzzy })
    return { 'words': words, 'refresh': 'always' }
  endif
endfun

