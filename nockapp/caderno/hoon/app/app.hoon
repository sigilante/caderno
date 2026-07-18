::  caderno: an executable notebook, as a NockApp.
::
::  A port of the %caderno Gall agent. The notebook model and the Hoon
::  evaluator are in /lib/caderno; this file is the kernel shell and the
::  HTTP surface.
::
::    POST /api/state    -> full state snapshot
::    POST /api/action   -> apply one action, respond with the snapshot
::    GET  *             -> the React UI's index.html
::
::  Only index.html is baked in here; its hashed JS/CSS bundles are served
::  by the runtime's ServeDir from WEB_DIR, mounted at a hardcoded /static.
::  They must not be served from Hoon: the driver's response path runs
::  +to-bytes-until-nul over the body, so a single 0x00 byte -- routine in
::  a minified bundle -- panics it, and the panic hook makes that fatal.
::
::  Every unmatched GET answers index.html rather than 404 so that a
::  client-side route survives a refresh. Unknown POST paths still 404.
::
::  Both answer 201, not 200, and that is load-bearing. The http driver
::  caches responses in a single global slot -- not a map, no URI key --
::  writing it on any effect whose status is exactly 200, and reading it
::  on any GET. So a 200 from POST /api/state becomes the response to
::  GET / until the cache expires. Answering 201 means the API never
::  writes that slot, so the only thing ever cached is the page GET /
::  itself returns, which is what a cache should hold anyway.
::
/+  *http
/+  *json
/+  cn=caderno
/=  *  /common/wrapper
::  The built UI's entry page, baked into the kernel as [@ud @t]. Rebuild it
::  with `vite build` and re-copy it whenever the UI changes: the bundle
::  filenames it references are content-hashed.
/*  index  %html  /app/site/index/html
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
    ::  Any GET is the app shell: `/`, and equally a deep link like
    ::  /notebook/main, which the client router resolves once it boots.
    ::  /static/* never reaches here -- the runtime serves it directly.
    ::
    ::  A 200 here is deliberate and safe, unlike a 200 from the API: the
    ::  driver's one cache slot then holds this page, which is the only
    ::  thing it should ever hold.
    ?:  ?=(%'GET' method)
      :_  state
      :_  ~
      ^-  effect
      [%res id %200 ['content-type' 'text/html']~ (to-octs q.index)]
    ::
    ?.  ?=(%'POST' method)
      [~[(error-response id 405 'method not allowed')] state]
    ::
    ?:  =('/api/state' uri)
      =/  s  (ensure-init:cn +.state)
      :_  state(+ s)
      ~[(json-response id 201 (store-to-json:cn s))]
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
    ~[(json-response id 201 (store-to-json:cn s))]
  --
--
((moat |) inner)
