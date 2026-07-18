::  caderno: an executable notebook, as a NockApp.
::
::  A port of the %caderno Gall agent. The notebook model and the Hoon
::  evaluator are in /lib/caderno; this file is the kernel shell and the
::  HTTP surface.
::
::  API, all POST -- the http driver's response cache is keyed on URI
::  alone and consulted only for GET, so keeping the API on POST sidesteps
::  it entirely:
::
::    POST /api/state    -> full state snapshot
::    POST /api/action   -> apply one action, respond with the snapshot
::
/+  *http
/+  *json
/+  cn=caderno
/=  *  /common/wrapper
=>
|%
+$  server-state  [%0 store:cn]
::
++  json-response
  |=  [id=@ status=@ud j=json]
  ^-  effect
  :*  %res  id  status
      ['content-type' 'application/json']~
      (to-octs (en-json j))
  ==
::
++  error-response
  |=  [id=@ status=@ud msg=@t]
  ^-  effect
  (json-response id status [%o (~(gas by *(map @t json)) ~[['error' [%s msg]]])])
::
++  landing
  ^-  @t
  '''
  <!doctype html>
  <html><head><meta charset="utf-8"><title>caderno</title></head>
  <body style="font-family:ui-monospace,monospace;max-width:44rem;margin:3rem auto">
    <h1>caderno</h1>
    <p>An executable notebook. The UI is not wired up yet; the API is:</p>
    <pre>
  POST /api/state
  POST /api/action   {"run-cell": {"id": 1}}
                     {"insert-cell": {"after": 1, "type": "code"}}
                     {"update-source": {"id": 1, "src": "(add 2 2)"}}
                     {"run-all": true}
                     {"reset-subject": true}
    </pre>
  </body></html>
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
    ::  types from the old kernel, so it cannot be trusted across one.
    ::  Notebooks and their recorded outputs survive.
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
      ~&  "caderno: malformed cause"
      !!
    =/  [id=@ uri=@t =method headers=(list header) body=(unit octs)]  +.u.sof-cau
    ::
    ?:  ?=(%'GET' method)
      :_  state
      :_  ~
      ^-  effect
      [%res id %200 ['content-type' 'text/html']~ (to-octs landing)]
    ::
    ?.  ?=(%'POST' method)
      [~[(error-response id 405 'method not allowed')] state]
    ::
    ?:  =('/api/state' uri)
      =/  s  (ensure-init:cn +.state)
      :_  state(+ s)
      ~[(json-response id 200 (store-to-json:cn s))]
    ::
    ?.  =('/api/action' uri)
      [~[(error-response id 404 'no such route')] state]
    ::
    ?~  body
      [~[(error-response id 400 'empty body')] state]
    ::
    ?~  parsed=(de-json q.u.body)
      [~[(error-response id 400 'body is not valid JSON')] state]
    ::
    ?~  act=(json-to-action:cn u.parsed)
      [~[(error-response id 400 'unrecognized action')] state]
    ::
    =/  s  (apply:cn u.act +.state)
    :_  state(+ s)
    ~[(json-response id 200 (store-to-json:cn s))]
  --
--
((moat |) inner)
