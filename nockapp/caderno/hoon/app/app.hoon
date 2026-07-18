::  caderno spike: evaluate Hoon source over HTTP
::
::  Phase 0 proof: that a hoonc-compiled NockApp kernel can
::  (a) capture its own compilation subject with !>(..add),
::  (b) ream/slap arbitrary user source against it,
::  (c) trap crashes with +mule, and
::  (d) accumulate the subject across evaluations via +slop.
::
/+  *http
/+  *json
/=  *  /common/wrapper
=>
|%
+$  server-state  [%0 subject=(unit vase)]
::
::  +fresh-subject: a vase of this kernel's own compilation context.
::
::    This is the whole spike. If `!>(..add)` yields the Hoon stdlib
::    here the way it does inside a Gall agent, the caderno eval core
::    ports verbatim.
::
++  fresh-subject  ^-(vase !>(.))
::
::  +tang-to-cord: render a stack trace as one cord
::
++  tang-to-cord
  |=  =tang
  ^-  @t
  %-  crip
  %-  zing
  %+  join  "\0a"
  %+  turn  (flop tang)
  |=(t=tank ~(ram re t))
::
::  +trim: strip trailing whitespace (curl adds a newline; +ream won't)
::
++  trim
  |=  t=@t
  ^-  @t
  =/  cs=(list @tD)  (flop (trip t))
  |-  ^-  @t
  ?~  cs  ''
  ?:  ?|(=(32 i.cs) =(10 i.cs) =(9 i.cs) =(13 i.cs))
    $(cs t.cs)
  (crip (flop cs))
::
::  +eval-hoon: evaluate source against a subject
::
::    Ported unchanged from desk/app/caderno.hoon:66. On success the
::    result is slopped onto the front of the subject, so cell N+1
::    reaches cell N's value at `-`. On failure the subject is untouched.
::
++  eval-hoon
  |=  [src=@t subj=vase]
  ^-  [out=@t new=vase]
  =/  parsed  (mule |.((ream src)))
  ?:  ?=(%| -.parsed)
    [(cat 3 'ParseError: ' (tang-to-cord p.parsed)) subj]
  =/  evaled  (mule |.((slap subj p.parsed)))
  ?:  ?=(%| -.evaled)
    [(cat 3 'EvalError: ' (tang-to-cord p.evaled)) subj]
  [(crip ~(ram re (sell p.evaled))) (slop p.evaled subj)]
::
++  json-probe
  |=  src=@t
  ^-  @t
  ::  round-trip: parse the body as JSON, wrap it, re-encode
  =/  parsed=(unit json)  (de-json src)
  ?~  parsed  'de-json: parse failed'
  %-  en-json
  [%o (~(gas by *(map @t json)) ~[['ok' [%b &]] ['echo' u.parsed]])]
::
++  usage
  ^-  @t
  '''
  caderno nockapp spike

    POST /eval    body is Hoon source; responds with the pretty-printed result
    POST /reset   discard the accumulated subject

  Try:
    curl -s -XPOST localhost:8080/eval -d '(add 2 2)'
    curl -s -XPOST localhost:8080/eval -d '(dec 0)'
    curl -s -XPOST localhost:8080/eval -d '=/(x 7 (mul x x))'
    curl -s -XPOST localhost:8080/eval -d '-'

  '''
--
::
=>
|%
++  moat  (keep server-state)
::
++  inner
  |_  state=server-state
  ::
  ++  load
    |=  arg=server-state
    ^-  server-state
    ::  Drop the accumulated subject on upgrade: a stored vase carries
    ::  types from the old kernel. Same reasoning as caderno's on-load.
    arg(subject ~)
  ::
  ++  peek
    |=  =path
    ^-  (unit (unit *))
    ~
  ::
  ++  poke
    |=  =ovum:moat
    ^-  [(list effect) server-state]
    =/  sof-cau=(unit cause)  ((soft cause) cause.input.ovum)
    ?~  sof-cau
      ~&  "cause incorrectly formatted!"
      !!
    =/  [id=@ uri=@t =method headers=(list header) body=(unit octs)]  +.u.sof-cau
    ::
    ?:  ?=(%'GET' method)
      :_  state
      :_  ~
      ^-  effect
      [%res id %200 ['content-type' 'text/plain']~ (to-octs usage)]
    ::
    ?.  ?=(%'POST' method)
      [~[[%res id %405 ~ ~]] state]
    ::
    ?:  =('/reset' uri)
      :_  state(subject ~)
      :_  ~
      ^-  effect
      [%res id %200 ['content-type' 'text/plain']~ (to-octs 'subject reset\0a')]
    ::
    ?:  =('/json' uri)
      ?~  body  [~[[%res id %400 ~ ~]] state]
      :_  state
      :_  ~
      ^-  effect
      :*  %res  id  %200  ['content-type' 'application/json']~
          (to-octs (cat 3 (json-probe (trim q.u.body)) '\0a'))
      ==
    ::
    ?.  =('/eval' uri)
      [~[[%res id %404 ~ ~]] state]
    ::
    ?~  body
      [~[[%res id %400 ~ (to-octs 'empty body\0a')]] state]
    ::
    =/  src=@t  (trim q.u.body)
    =/  subj=vase  ?~(subject.state fresh-subject u.subject.state)
    =/  res  (eval-hoon src subj)
    :_  state(subject `new.res)
    :_  ~
    ^-  effect
    :*  %res  id  %200
        ['content-type' 'text/plain']~
        (to-octs (cat 3 out.res '\0a'))
    ==
  --
--
((moat |) inner)
