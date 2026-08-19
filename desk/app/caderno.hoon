::  /app/caderno.hoon
::  caderno: hoon notebook
::
/-  *caderno, *sole
/+  default-agent, dbug
::
|%
::  nbs maps stable @t id to notebook; active is the focused notebook id.
+$  state-4
  $:  nbs=(map @t notebook)
      active=@t
      ksession=(unit kernel-session)
      counter=@ud
      hoon-subject=vase
  ==
::  state-5 adds notebook publishing over Gall subscription:
::    published: local notebook ids exposed on /published/<id> (public)
::    follows:   read-only mirrors of remote notebooks we subscribe to
+$  state-5
  $:  nbs=(map @t notebook)
      active=@t
      ksession=(unit kernel-session)
      counter=@ud
      hoon-subject=vase
      published=(set @t)
      follows=(map [who=@p id=@t] notebook)
  ==
::  state-6 gives each notebook its own sole session.  Under state-5 every
::  notebook sharing a shoe kernel shared one session named %caderno, and so
::  shared one subject: bindings made in one notebook leaked into the next.
+$  state-6
  $:  nbs=(map @t notebook)
      active=@t
      ksessions=(map @t kernel-session)
      counter=@ud
      hoon-subject=vase
      published=(set @t)
      follows=(map [who=@p id=@t] notebook)
    ::  agents last observed to be shoe agents.  Only the UI can establish
    ::  this (see /x/kernels), so it is cached here rather than recomputed.
      kernels=(set @t)
  ==
+$  versioned-state  $%([%4 state-4] [%5 state-5] [%6 state-6])
+$  card  card:agent:gall

++  find-cell
  |=  [id=cell-id cs=(list cell)]
  ^-  (unit cell)
  |-
  ?~  cs  ~
  ?.  =(id id.i.cs)  $(cs t.cs)
  `i.cs

++  replace-cell
  |=  [id=cell-id new=cell cs=(list cell)]
  ^-  (list cell)
  (turn cs |=(c=cell ?:(=(id id.c) new c)))

++  insert-after-cell
  ::  Insert `new` immediately after the cell whose id = `aid`.
  ::  If `aid` is not found, append `new` at the end.
  |=  [aid=cell-id new=cell cs=(list cell)]
  ^-  (list cell)
  |-
  ?~  cs  ~[new]
  ?:  =(aid id.i.cs)
    (weld ~[i.cs new] t.cs)
  [i.cs $(cs t.cs)]

++  tang-to-cord
  |=  t=tang
  ^-  @t
  (crip (zing (turn t |=(=tank ~(ram re tank)))))

++  fresh-subject
  ^-  vase
  !>(..zuse)

::  Evaluate a Hoon cord against a subject vase.
::  Returns the output to show and the new accumulated subject.
::  On success: new-subject = slop(result, old-subject) so the result is
::  at `-` and the old subject (with stdlib) is accessible at `+`.
::  On error: subject is returned unchanged.
++  eval-hoon
  |=  [src=@t subj=vase]
  ^-  [output vase]
  =/  parsed  (mule |.((ream src)))
  ?:  ?=(%| -.parsed)
    [[%error 'ParseError' (tang-to-cord p.parsed)] subj]
  =/  evaled  (mule |.((slap subj p.parsed)))
  ?:  ?=(%| -.evaled)
    [[%error 'EvalError' (tang-to-cord p.evaled)] subj]
  :-  [%text (crip ~(ram re (sell p.evaled)))]
  (slop p.evaled subj)

++  nb-list-items
  |=  ns=(map @t notebook)
  ^-  (list [id=@t title=@t])
  (turn ~(tap by ns) |=([id=@t nb=notebook] [id title.nb]))
::
++  follows-items
  |=  fs=(map [who=@p id=@t] notebook)
  ^-  (list [who=@p id=@t title=@t])
  (turn ~(tap by fs) |=([[who=@p id=@t] nb=notebook] [who id title.nb]))
::
++  published-catalog
  ::  [id title] for each published notebook still present in nbs.
  |=  [pub=(set @t) ns=(map @t notebook)]
  ^-  (list [id=@t title=@t])
  %+  murn  ~(tap in pub)
  |=  id=@t
  ^-  (unit [@t @t])
  ?~  nb=(~(get by ns) id)  ~
  `[id title.u.nb]

++  any-key
  ::  Returns any key from a non-null map.  Used when we need to pick a
  ::  fallback notebook after deleting the active one.
  |=  ns=(map @t notebook)
  ^-  @t
  ?>  ?=(^ ns)
  p.n.ns

++  session-name
  ::  Sole session name for a notebook: caderno-<id> where the notebook id is
  ::  a valid @ta term, else caderno-<hash of it>.  The name becomes a path
  ::  element (/sole/<who>/<ses>), so it has to be path-safe.  Locally minted
  ::  ids always are, but %fork inherits an id from a remote ship, which we
  ::  do not control.  The caderno- prefix is what the UI filters on to tell
  ::  our sessions apart from other clients' on the same kernel.
  |=  id=@t
  ^-  @ta
  ?:  ((sane %ta) id)  (rap 3 ~['caderno-' id])
  (rap 3 ~['caderno-' (scot %uv (end [3 16] (shax id)))])
::
++  session-wire  |=(ses=@ta `wire`/caderno/session/[ses])
++  eval-wire     |=(ses=@ta `wire`/caderno/eval/[ses])
::
++  session-by-ses
  ::  Which notebook owns this sole session?  Signs arrive on a wire keyed by
  ::  session name, and +session-name is not always invertible, so look it up.
  |=  [kss=(map @t kernel-session) ses=@ta]
  ^-  (unit [id=@t ks=kernel-session])
  =/  l  ~(tap by kss)
  |-
  ?~  l  ~
  ?:  =(ses ses.q.i.l)  `[p.i.l q.i.l]
  $(l t.l)
::
++  live-kernels
  ::  cached shoe agents that are still running, sorted
  |=  [ks=(set @t) our=@p now=@da]
  ^-  (list @t)
  =/  live  (running-agents our now)
  (sort ~(tap in (~(int in ks) live)) aor)
::
++  running-agents
  ::  Every running gall agent across all desks.  %ge and %cd are vane scries
  ::  and always resolve; suspended or unloadable desks are skipped via mule.
  |=  [our=@p now=@da]
  ^-  (set @t)
  =/  all-desks  .^((set desk) %cd (en-beam [[our %$ [%da now]] /]))
  %-  ~(gas in *(set @t))
  ^-  (list @t)
  %-  zing
  %+  turn  ~(tap in all-desks)
  |=  =desk
  ^-  (list @t)
  =/  res
    %-  mule
    |.  .^((set [=dude:gall live=?]) %ge /(scot %p our)/[desk]/(scot %da now)/$)
  ?:  ?=(%| -.res)  ~
  %+  murn  ~(tap in p.res)
  |=([=dude:gall live=?] ?:(live [~ `@t`dude] ~))
::
++  read-seeds
  ::  Load seed notebooks from /seed/<id>.json in this desk (id = filename).
  ::  Demo content lives as data files, not hoon literals; on-init reads them.
  |=  [our=@p now=@da]
  ^-  (map @t notebook)
  =/  a  (mule |.(.^(arch %cy (en-beam [[our %caderno [%da now]] /seed]))))
  ?:  ?=(%| -.a)  ~
  %-  ~(gas by *(map @t notebook))
  %+  murn  ~(tap in ~(key by dir.p.a))
  |=  id=@ta
  ^-  (unit [@t notebook])
  =/  fp  (en-beam [[our %caderno [%da now]] /seed/[id]/json])
  =/  res  (mule |.((json-to-notebook .^(json %cx fp))))
  ?:(?=(%| -.res) ~ `[`@t`id p.res])

++  nbs-to-soba
  ::  Build Clay soba (file mutations) for writing all notebooks as JSON text.
  |=  ns=(map @t notebook)
  ^-  (list [path miso:clay])
  %+  turn  ~(tap by ns)
  |=  [id=@t nb=notebook]
  :-  (welp /notebook `path`[`@ta`id /txt])
  `miso:clay`[%ins `cage`[%txt !>(~[(en:json:html (update-to-json [%state id nb]))])]]

++  update-to-json
  |=  upd=update
  ^-  json
  ?-  -.upd
      %state
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['state' [%o (~(gas by *(map @t json)) ~[['id' [%s id.upd]] ['nb' (notebook-to-json nb.upd)]])]]]
      %kernels
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['kernels' [%a (turn items.upd |=(k=@t [%s k]))]]]
      %nb-list
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['nb-list' [%a (turn items.upd |=([nb-id=@t nb-title=@t] [%o (~(gas by *(map @t json)) ~[['id' [%s nb-id]] ['title' [%s nb-title]]])]))]]]
      %cell-output
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-output' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]] ['out' (output-to-json out.upd)] ['count' [%n (scot %ud count.upd)]]])]]]
      %cell-status
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-status' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]] ['status' [%s (scot %tas status.upd)]]])]]]
      %cell-added
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-added' [%o (~(gas by *(map @t json)) ~[['after' ?~(after.upd ~ [%n (scot %ud u.after.upd)])] ['c' (cell-to-json c.upd)]])]]]
      %cell-deleted
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-deleted' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]]])]]]
      %log-mounted
    [%o (~(gas by *(map @t json)) ~[['log-mounted' [%b %.y]]])]
      %log-committed
    [%o (~(gas by *(map @t json)) ~[['log-committed' [%b %.y]]])]
      %published
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['published' [%a (turn ~(tap in ids.upd) |=(id=@t [%s id]))]]]
      %follows
    :-  %o
    %-  ~(gas by *(map @t json))
    :~  :-  'follows'
        :-  %a
        %+  turn  items.upd
        |=  [who=@p id=@t title=@t]
        :-  %o
        %-  ~(gas by *(map @t json))
        ~[['who' [%s (scot %p who)]] ['id' [%s id]] ['title' [%s title]]]
    ==
      %published-list
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['published-list' [%a (turn items.upd catalog-item-to-json)]]]
      %lookup
    :-  %o
    %-  ~(gas by *(map @t json))
    :~  :-  'lookup'
        :-  %o
        %-  ~(gas by *(map @t json))
        :~  ['who' [%s (scot %p who.upd)]]
            ['items' [%a (turn items.upd catalog-item-to-json)]]
    ==  ==
  ==
::
++  catalog-item-to-json
  |=  [id=@t title=@t]
  ^-  json
  :-  %o
  (~(gas by *(map @t json)) ~[['id' [%s id]] ['title' [%s title]]])
::
++  json-to-catalog
  ::  parse a %published-list fact into [id title] pairs.
  |=  j=json
  ^-  (list [id=@t title=@t])
  ?>  ?=([%o *] j)
  =/  arr  (~(got by p.j) 'published-list')
  ?>  ?=([%a *] arr)
  %+  turn  p.arr
  |=  it=json
  ?>  ?=([%o *] it)
  [(so:dejs:format (~(got by p.it) 'id')) (so:dejs:format (~(got by p.it) 'title'))]

++  broadcast
  |=  upd=update
  ^-  card
  [%give %fact [[%notebook ~] ~] %json !>((update-to-json upd))]
::
++  pub-fact
  ::  push the full state of a published notebook to its /published/<id> subs.
  |=  [id=@t nb=notebook]
  ^-  card
  [%give %fact ~[/published/[id]] %json !>((update-to-json [%state id nb]))]
::
++  catalog-fact
  ::  push the published catalog to /published-list subscribers (lookers).
  |=  [pub=(set @t) ns=(map @t notebook)]
  ^-  card
  [%give %fact ~[/published-list] %json !>((update-to-json [%published-list (published-catalog pub ns)]))]

++  flatten-effects
  |=  efx=sole-effect
  ^-  (list sole-effect)
  ?:  ?=([%mor *] efx)
    (zing (turn p.efx flatten-effects))
  ~[efx]

++  output-to-json
  |=  out=output
  ^-  json
  ?-  -.out
      %text
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['text' [%s data.out]]]
      %error
    :-  %o
    %-  ~(gas by *(map @t json))
    :~  ['ename' [%s ename.out]]
        ['evalue' [%s evalue.out]]
    ==
  ==

++  cell-to-json
  |=  c=cell
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['id' [%n (scot %ud id.c)]]
      ['type' [%s (scot %tas type.c)]]
      ['source' [%s source.c]]
      ['exec_count' ?~(exec-count.c ~ [%n (scot %ud u.exec-count.c)])]
      ['outputs' [%a (turn outputs.c output-to-json)]]
  ==

::  nbformat: notebook schema version, stamped into every serialized notebook
::  (wire + Clay log). Bump when the notebook shape changes; readers gate on it.
++  nbformat  1
::
++  notebook-to-json
  |=  nb=notebook
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['nbformat' [%n (scot %ud nbformat)]]
      ['title' [%s title.nb]]
      ['kernel' [%s (scot %tas kernel.nb)]]
      ['cells' [%a (turn cells.nb cell-to-json)]]
  ==
::  JSON -> state parsers: inverses of the *-to-json arms above, used to
::  re-import notebooks written to %caderno-log.
::
++  json-numb
  ::  tolerant JSON-number -> @ud: strips the dot separators scot %ud emits.
  |=  j=json
  ^-  @ud
  ?>  ?=([%n *] j)
  (rash (crip (skip (trip p.j) |=(c=@tD =('.' c)))) dem)
::
++  json-to-output
  |=  j=json
  ^-  output
  ?>  ?=([%o *] j)
  =/  m  p.j
  ?:  (~(has by m) 'text')
    [%text (so:dejs:format (~(got by m) 'text'))]
  :+  %error
    (so:dejs:format (~(got by m) 'ename'))
  (so:dejs:format (~(got by m) 'evalue'))
::
++  json-to-cell
  |=  j=json
  ^-  cell
  ?>  ?=([%o *] j)
  =/  m     p.j
  =/  outs  (~(got by m) 'outputs')
  =/  ec    (~(got by m) 'exec_count')
  =/  tp    (so:dejs:format (~(got by m) 'type'))
  :*  id=(json-numb (~(got by m) 'id'))
      type=`cell-type`?:(=(tp 'markdown') %markdown %code)
      source=(so:dejs:format (~(got by m) 'source'))
      outputs=?>(?=([%a *] outs) (turn p.outs json-to-output))
      exec-count=?~(ec ~ `(json-numb ec))
  ==
::
++  json-to-notebook
  |=  j=json
  ^-  notebook
  ?>  ?=([%o *] j)
  =/  m   p.j
  ::  gate on nbformat: absent means legacy (pre-versioning) = format 1; a
  ::  newer format than we understand crashes here so callers skip/reject it
  ::  rather than misparse a future schema.
  =/  fmt=@ud
    ?~  v=(~(get by m) 'nbformat')  1
    (json-numb u.v)
  ?>  (lte fmt nbformat)
  =/  cs  (~(got by m) 'cells')
  :*  cells=?>(?=([%a *] cs) (turn p.cs json-to-cell))
      kernel=`@tas`(so:dejs:format (~(got by m) 'kernel'))
      title=(so:dejs:format (~(got by m) 'title'))
  ==
::
++  json-to-state
  ::  parse a logged notebook file, {state:{id,nb}} -> [id notebook]
  |=  j=json
  ^-  [@t notebook]
  ?>  ?=([%o *] j)
  =/  st  (~(got by p.j) 'state')
  ?>  ?=([%o *] st)
  =/  m  p.st
  :-  (so:dejs:format (~(got by m) 'id'))
  (json-to-notebook (~(got by m) 'nb'))
--

=|  state-6
=*  state  -
^-  agent:gall
%-  agent:dbug
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)

++  on-init
  ^-  (quip card _this)
  ::  seed from /seed/*.json; fall back to one blank notebook if there are none
  =/  seeds  (read-seeds our.bowl now.bowl)
  =?  seeds  =(0 ~(wyt by seeds))
    (~(put by seeds) 'main' [~ %hoon 'untitled'])
  =/  active=@t  ?:((~(has by seeds) 'hs-syntax') 'hs-syntax' (any-key seeds))
  `this(nbs seeds, active active, ksessions ~, counter 100, hoon-subject fresh-subject, published ~, follows ~, kernels ~)

++  on-save
  !>(`versioned-state`[%6 nbs active ksessions counter hoon-subject published follows kernels])

++  on-load
  |=  old=vase
  ^-  (quip card _this)
  ::  Always reset hoon-subject: stored vases are stale after kernel upgrades.
  =/  try  (mule |.(!<(versioned-state old)))
  ?.  ?=(%& -.try)
    `this(nbs (~(put by *(map @t notebook)) 'main' [~ %hoon 'untitled']), active 'main', ksessions ~, counter 0, hoon-subject fresh-subject, published ~, follows ~, kernels ~)
  ::  Migrate any prior version up to state-6, and collect the leaves needed
  ::  to drop whatever sessions that version was holding.  Every session goes
  ::  across an upgrade: a queued %eval-command cannot survive one, and the
  ::  leave is what makes shoe drop the session (see +on-leave in /lib/shoe),
  ::  so the next run starts cold instead of inheriting a half-built subject.
  ::  state-4 and state-5 held a single session on the undifferentiated
  ::  /caderno/session wire; state-6 holds one per notebook.
  =/  mig
    ^-  [state-6 (list card)]
    ?-    -.p.try
        %6
      =/  o=state-6  +.p.try
      :-  o
      %+  turn  ~(tap by ksessions.o)
      |=  [id=@t ks=kernel-session]
      ^-  card
      [%pass (session-wire ses.ks) %agent [our.bowl agent.ks] %leave ~]
    ::
        %5
      =/  o=state-5  +.p.try
      :-  [nbs.o active.o ~ counter.o hoon-subject.o published.o follows.o ~]
      ?~  ksession.o  ~
      ~[[%pass /caderno/session %agent [our.bowl agent.u.ksession.o] %leave ~]]
    ::
        %4
      =/  o=state-4  +.p.try
      :-  [nbs.o active.o ~ counter.o hoon-subject.o ~ ~ ~]
      ?~  ksession.o  ~
      ~[[%pass /caderno/session %agent [our.bowl agent.u.ksession.o] %leave ~]]
    ==
  =/  s=state-6            -.mig
  =/  cleanup=(list card)  +.mig
  :-  cleanup
  %=  this
    nbs           nbs.s
    active        active.s
    ksessions     ~
    counter       counter.s
    hoon-subject  fresh-subject
    published     published.s
    follows       follows.s
    kernels       kernels.s
  ==

++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %cnb-action
    =/  act  !<(action vase)
    =/  nb  (need (~(get by nbs) active))
    ::  run the action, then re-push the active notebook to its followers if it
    ::  is published (all mutations target the active notebook).
    =^  cards=(list card)  this
      ?-  -.act
        %run-cell
      =/  id  id.act
      =/  c  (find-cell id cells.nb)
      ?~  c  `this
      ?.  =(%code type.u.c)  `this
      =/  new-count  +(counter)
      ::  hoon kernel: evaluate against accumulated subject
      ?:  =(%hoon kernel.nb)
        =/  res  (eval-hoon source.u.c hoon-subject)
        =/  out  -.res
        =/  new-subj  +.res
        =/  new-cell  u.c(outputs [out ~], exec-count `new-count)
        =/  new-nb  nb(cells (replace-cell id new-cell cells.nb))
        =/  status  ?-(-.out %text %done, %error %error)
        :_  this(nbs (~(put by nbs) active new-nb), counter new-count, hoon-subject new-subj)
        :~  (broadcast [%cell-status id %running])
            (broadcast [%cell-output id out new-count])
            (broadcast [%cell-status id status])
        ==
      ::  shoe kernel: delegate to this notebook's own sole session
      =/  src  source.u.c
      =/  ses  (session-name active)
      =/  new-nbs
        %+  ~(put by nbs)  active
        nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb))
      =/  running-card  (broadcast [%cell-status id %running])
      =/  watch-card=card
        :*  %pass  (session-wire ses)  %agent
            [our.bowl kernel.nb]
            %watch  /sole/(scot %p our.bowl)/[ses]
        ==
      =/  cold-ks  ^-  kernel-session
        :*  agent=kernel.nb
            ses=ses
            pending=`[id src]
            queue=~
            accum=~
            ready=%.n
        ==
      ?~  ks=(~(get by ksessions) active)
        ::  no session for this notebook: cold start.  the queued command is
        ::  dispatched when shoe's initial %pro confirms the session is ready.
        :_  %=  this
              nbs        new-nbs
              ksessions  (~(put by ksessions) active cold-ks)
              counter    new-count
            ==
        ~[running-card watch-card]
      =/  kz=kernel-session  u.ks
      =/  same-kernel=?  =(agent.kz kernel.nb)
      ::  Reuse the session if it belongs to the kernel this notebook is set
      ::  to and has been confirmed ready by a %pro.
      ::
      ::  Liveness comes from the subscription, not from a scry.  It is
      ::  tempting to confirm against the kernel's /x/sole/sessions, but a
      ::  %gx scry into an agent that does not answer the path blocks, and a
      ::  block is NOT catchable by mule -- it bails with %need straight
      ::  through the poke.  Any kernel whose /lib/shoe predates the
      ::  /x/sole/sessions scry would therefore crash the poke rather than
      ::  report "no session".  Gall does the same for an agent whose
      ::  +on-peek crashes, so there is no safe in-agent probe at all.
      ::
      ::  The subscription is sufficient anyway: shoe only drops a session on
      ::  +on-leave, which happens because we sent one or because the agent
      ::  went away and kicked us, and %kick already clears the record here.
      ::  The scry's place is the UI, where eyre turns a block into a 404.
      ?:  &(same-kernel ready.kz)
        :_  %=  this
              nbs        new-nbs
              ksessions  (~(put by ksessions) active kz(pending `[id src], queue ~, accum ~))
              counter    new-count
            ==
        :~  running-card
            :*  %pass  (eval-wire ses)  %agent
                [our.bowl kernel.nb]
                %poke  %eval-command
                !>([ses (trip src)])
            ==
        ==
      ?:  &(same-kernel !ready.kz)
        ::  watch already in flight; only queue.  %pro will dispatch it.
        :_  %=  this
              nbs        new-nbs
              ksessions  (~(put by ksessions) active kz(pending `[id src], queue ~, accum ~))
              counter    new-count
            ==
        ~[running-card]
      ::  stale: the kernel changed, or shoe dropped the session.  leave before
      ::  re-watching so we do not strand it, then start cold.
      :_  %=  this
            nbs        new-nbs
            ksessions  (~(put by ksessions) active cold-ks)
            counter    new-count
          ==
      :~  [%pass (session-wire ses.kz) %agent [our.bowl agent.kz] %leave ~]
          running-card
          watch-card
      ==
    ::
        %run-all
      ::  Runs all code cells top-to-bottom with a fresh subject.
      ::  Each cell's result is accumulated so later cells can reference
      ::  earlier results.
      ::
      ::  A shoe kernel cannot be folded over the way the hoon one can: each
      ::  cell is a round trip, so the run is driven by the session instead.
      ::  Restart it (leave, then re-watch) so the run starts from a clean
      ::  subject the way fresh-subject does for hoon, queue every code cell,
      ::  and let the %pro handler in +on-agent dispatch them one at a time.
      ::  Like the hoon path, a cell that errors does not stop the run.
      ?.  =(%hoon kernel.nb)
        =/  jobs=(list [id=cell-id src=@t])
          %+  turn  (skim cells.nb |=(c=cell =(%code type.c)))
          |=(c=cell [id.c source.c])
        ?~  jobs  `this
        =/  ses  (session-name active)
        =/  new-count  +(counter)
        ::  only the first cell's exec-count is known now; the rest are
        ::  stamped as each is dispatched
        =/  new-cells
          =/  c  (find-cell id.i.jobs cells.nb)
          ?~  c  cells.nb
          (replace-cell id.i.jobs u.c(exec-count `new-count) cells.nb)
        =/  ks  (~(get by ksessions) active)
        =/  cleanup=(list card)
          ?~  ks  ~
          ~[[%pass (session-wire ses.u.ks) %agent [our.bowl agent.u.ks] %leave ~]]
        :_  %=  this
              nbs        (~(put by nbs) active nb(cells new-cells))
              counter    new-count
              ksessions
                %+  ~(put by ksessions)  active
                ^-  kernel-session
                :*  agent=kernel.nb
                    ses=ses
                    pending=`i.jobs
                    queue=t.jobs
                    accum=~
                    ready=%.n
                ==
            ==
        %+  weld  cleanup
        ^-  (list card)
        :~  (broadcast [%cell-status id.i.jobs %running])
            :*  %pass  (session-wire ses)  %agent
                [our.bowl kernel.nb]
                %watch  /sole/(scot %p our.bowl)/[ses]
            ==
        ==
      =/  code-cells  (skim cells.nb |=(c=cell =(%code type.c)))
      =/  cs=(list cell)   cells.nb
      =/  cd=(list card)   ~
      =/  ct=@ud           counter
      =/  subj             fresh-subject
      |-
      ?~  code-cells
        :_  this(nbs (~(put by nbs) active nb(cells cs)), counter ct, hoon-subject subj)
        cd
      =/  c   i.code-cells
      =/  new-ct  +(ct)
      =/  res  (eval-hoon source.c subj)
      =/  out  -.res
      =/  new-subj  +.res
      =/  new-cell  c(outputs [out ~], exec-count `new-ct)
      =/  status  ?-(-.out %text %done, %error %error)
      =/  new-cd
        %+  weld  cd
        :~  (broadcast [%cell-status id.c %running])
            (broadcast [%cell-output id.c out new-ct])
            (broadcast [%cell-status id.c status])
        ==
      $(code-cells t.code-cells, cs (replace-cell id.c new-cell cs), cd new-cd, ct new-ct, subj new-subj)
    ::
        %insert-cell
      =/  new-id  counter
      =/  new-cell  ^-  cell
        :*  id=new-id
            type=type.act
            source=''
            outputs=~
            exec-count=~
        ==
      =/  new-cells
        ?~  after.act
          (snoc cells.nb new-cell)
        (insert-after-cell u.after.act new-cell cells.nb)
      =/  new-nb  nb(cells new-cells)
      :_  this(nbs (~(put by nbs) active new-nb), counter +(counter))
      ~[(broadcast [%cell-added after.act new-cell])]
    ::
        %delete-cell
      =/  id  id.act
      =/  new-nb  nb(cells (skip cells.nb |=(c=cell =(id id.c))))
      :_  this(nbs (~(put by nbs) active new-nb))
      ~[(broadcast [%cell-deleted id])]
    ::
        %update-source
      =/  id  id.act
      =/  c  (find-cell id cells.nb)
      ?~  c  `this
      =/  new-nb  nb(cells (replace-cell id u.c(source src.act) cells.nb))
      `this(nbs (~(put by nbs) active new-nb))
    ::
        %set-kernel
      ::  Changing kernel invalidates this notebook's session: its subject
      ::  belongs to the old kernel.  Leave it so shoe reaps it.
      =/  new-nbs  (~(put by nbs) active nb(kernel kernel.act))
      ?~  ks=(~(get by ksessions) active)
        `this(nbs new-nbs)
      ?:  =(agent.u.ks kernel.act)
        `this(nbs new-nbs)
      :_  this(nbs new-nbs, ksessions (~(del by ksessions) active))
      ~[[%pass (session-wire ses.u.ks) %agent [our.bowl agent.u.ks] %leave ~]]
    ::
        %reset-subject
      ::  Resets only the active notebook -- sessions are per-notebook now.
      ::  For a shoe kernel the leave is the reset: /lib/shoe drops the
      ::  session on +on-leave, so the next run starts cold.
      =/  ks  (~(get by ksessions) active)
      =/  cleanup=(list card)
        ?~  ks  ~
        ~[[%pass (session-wire ses.u.ks) %agent [our.bowl agent.u.ks] %leave ~]]
      :-  cleanup
      this(hoon-subject fresh-subject, ksessions (~(del by ksessions) active))
        %set-cell-type
      =/  c  (find-cell id.act cells.nb)
      ?~  c  `this
      =/  new-cell  u.c(type type.act, outputs ~, exec-count ~)
      `this(nbs (~(put by nbs) active nb(cells (replace-cell id.act new-cell cells.nb))))
        %set-title
      =/  new-nb   nb(title title.act)
      =/  new-nbs  (~(put by nbs) active new-nb)
      ::  followers get the new title via the published re-push below; lookers
      ::  need an explicit catalog refresh (titles show in the catalog).
      :_  this(nbs new-nbs)
      %+  weld
        ^-  (list card)
        ~[(broadcast [%nb-list (nb-list-items new-nbs)])]
      ^-  (list card)
      ?.  (~(has in published) active)  ~
      ~[(catalog-fact published new-nbs)]
        %new-notebook
      =/  new-id  (crip (weld "nb-" (trip (scot %ud counter))))
      =/  new-nb  ^-  notebook
        :*  cells=~
            kernel=%hoon
            title='untitled'
        ==
      =/  new-nbs  (~(put by nbs) new-id new-nb)
      :_  this(nbs new-nbs, active new-id, counter +(counter))
      :~  (broadcast [%nb-list (nb-list-items new-nbs)])
          (broadcast [%state new-id new-nb])
      ==
        %switch-notebook
      =/  target-id  id.act
      ?.  (~(has by nbs) target-id)  `this
      =/  target-nb  (need (~(get by nbs) target-id))
      :_  this(active target-id)
      ~[(broadcast [%state target-id target-nb])]
        %delete-notebook
      =/  del-id  id.act
      ?.  (~(has by nbs) del-id)  `this
      ::  refuse to delete the last notebook
      ?:  =(~(wyt by nbs) 1)  `this
      =/  new-nbs  (~(del by nbs) del-id)
      ::  if deleting active, switch to the first remaining notebook
      =/  new-active=@t
        ?:  =(del-id active)
          (any-key new-nbs)
        active
      =/  new-active-nb  (need (~(get by new-nbs) new-active))
      ::  deleting a published notebook implies unpublishing it: drop it from
      ::  the set, kick its followers, and refresh the catalog for lookers.
      =/  was-pub  (~(has in published) del-id)
      =/  new-pub  (~(del in published) del-id)
      ::  a deleted notebook's sole session has nothing left to belong to
      =/  dks  (~(get by ksessions) del-id)
      =/  cleanup=(list card)
        ?~  dks  ~
        ~[[%pass (session-wire ses.u.dks) %agent [our.bowl agent.u.dks] %leave ~]]
      :_  %=  this
            nbs        new-nbs
            active     new-active
            published  new-pub
            ksessions  (~(del by ksessions) del-id)
          ==
      %+  weld  cleanup
      %+  weld
        ^-  (list card)
        :~  (broadcast [%nb-list (nb-list-items new-nbs)])
            (broadcast [%state new-active new-active-nb])
        ==
      ^-  (list card)
      ?.  was-pub  ~
      :~  [%give %kick ~[/published/[del-id]] ~]
          (broadcast [%published new-pub])
          (catalog-fact new-pub new-nbs)
      ==
        %mount-log
      ::  create %caderno-log desk and mount it to unix (idempotent)
      =/  all-desks  .^((set desk) %cd (en-beam [[our.bowl %$ [%da now.bowl]] /]))
      ?:  (~(has in all-desks) %caderno-log)
        :_  this
        ~[(broadcast [%log-mounted ~])]
      ::  read bootstrap files from %base
      =/  base-paths=(list path)
        :~  /mar/noun/hoon  /mar/hoon/hoon  /mar/txt/hoon
            /mar/kelvin/hoon  /mar/json/hoon  /sys/kelvin
        ==
      =/  init-files=(map path page:clay)
        %-  ~(gas by *(map path page:clay))
        %+  turn  base-paths
        |=  =path
        :-  path
        ^-  page:clay
        [(rear path) .^(* %cx (en-beam [[our.bowl %base [%da now.bowl]] path]))]
      =/  make-desk=note-arvo  (new-desk:cloy %caderno-log ~ init-files)
      =/  log-bem=beam  [[our.bowl %caderno-log [%da now.bowl]] /]
      :_  this
      :~  [%pass /caderno/hood/pass %agent [our.bowl %hood] %poke %helm-pass !>(make-desk)]
          [%pass /caderno/hood/mount %agent [our.bowl %hood] %poke %kiln-mount !>([(en-beam log-bem) %caderno-log])]
          (broadcast [%log-mounted ~])
      ==
        %commit-log
      ::  Mirror state to %caderno-log: write every current notebook, and delete
      ::  the files of notebooks removed from state since the last commit — so a
      ::  later %import-log doesn't resurrect them. Guarded on the log desk.
      =/  ins-soba  (nbs-to-soba nbs)
      =/  all-desks  .^((set desk) %cd (en-beam [[our.bowl %$ [%da now.bowl]] /]))
      =/  del-soba=(list [path miso:clay])
        ?.  (~(has in all-desks) %caderno-log)  ~
        =/  a  (mule |.(.^(arch %cy (en-beam [[our.bowl %caderno-log [%da now.bowl]] /notebook]))))
        ?:  ?=(%| -.a)  ~
        %+  murn  ~(tap in ~(key by dir.p.a))
        |=  id=@ta
        ^-  (unit [path miso:clay])
        ?:  (~(has by nbs) `@t`id)  ~
        `[(welp /notebook `path`[id /txt]) [%del ~]]
      =/  soba  (weld ins-soba del-soba)
      :_  this
      :~  [%pass /caderno/clay %arvo %c [%info %caderno-log [%& soba]]]
          [%pass /caderno/hood/commit %agent [our.bowl %hood] %poke %kiln-commit !>([%caderno-log %.n])]
          (broadcast [%log-committed ~])
      ==
        %import-log
      ::  read notebooks back from %caderno-log into state (Clay -> gall).
      ::  Each /notebook/<id>/txt holds one line of {state:{id,nb}} JSON; a
      ::  file that is missing, unreadable, or malformed is skipped via mule.
      ::  Imported notebooks override in-memory ones with the same id.
      ::
      ::  No-op if the log desk was never created (MOUNT makes it): scrying a
      ::  nonexistent desk would bail, so gate on the desk list like %mount-log.
      =/  all-desks  .^((set desk) %cd (en-beam [[our.bowl %$ [%da now.bowl]] /]))
      ?.  (~(has in all-desks) %caderno-log)
        :_  this
        ~[(broadcast [%nb-list (nb-list-items nbs)])]
      =/  =arch
        .^(arch %cy (en-beam [[our.bowl %caderno-log [%da now.bowl]] /notebook]))
      =/  imported=(map @t notebook)
        %-  ~(gas by *(map @t notebook))
        %+  murn  ~(tap in ~(key by dir.arch))
        |=  id=@ta
        ^-  (unit [@t notebook])
        =/  fp  (en-beam [[our.bowl %caderno-log [%da now.bowl]] /notebook/[id]/txt])
        =/  res  (mule |.((json-to-state (need (de:json:html (rap 3 .^(wain %cx fp)))))))
        ?:(?=(%| -.res) ~ `p.res)
      =/  merged=(map @t notebook)  (~(uni by nbs) imported)
      =/  new-active=@t
        ?:  (~(has by merged) active)  active
        =/  ps  ~(tap by merged)
        ?~(ps active p.i.ps)
      :_  this(nbs merged, active new-active)
      :~  (broadcast [%nb-list (nb-list-items merged)])
          (broadcast [%state new-active (need (~(get by merged) new-active))])
      ==
    ::
        %publish
      ?.  (~(has by nbs) id.act)  `this
      =/  pub  (~(put in published) id.act)
      :_  this(published pub)
      :~  (broadcast [%published pub])
          (catalog-fact pub nbs)
      ==
    ::
        %unpublish
      =/  pub  (~(del in published) id.act)
      :_  this(published pub)
      :~  [%give %kick ~[/published/[id.act]] ~]
          (broadcast [%published pub])
          (catalog-fact pub nbs)
      ==
    ::
        %set-kernels
      ::  result of a UI sweep; see /x/kernels for why the UI has to do it
      =/  ks  (~(gas in *(set @t)) ids.act)
      :_  this(kernels ks)
      ~[(broadcast [%kernels (live-kernels ks our.bowl now.bowl)])]
    ::
        %rescan-kernels
      ::  drop the cache; the UI sees an empty /x/kernels and sweeps again
      :_  this(kernels ~)
      ~[(broadcast [%kernels ~])]
    ::
        %lookup
      ::  leave any prior sub on this wire first, so re-looking-up the same ship
      ::  gets a fresh catalog instead of a duplicate-wire nack.
      :_  this
      :~  [%pass /lookup/(scot %p who.act) %agent [who.act %caderno] %leave ~]
          :*  %pass  /lookup/(scot %p who.act)
              %agent  [who.act %caderno]  %watch  /published-list
      ==  ==
    ::
        %unlookup
      :_  this
      :~  :*  %pass  /lookup/(scot %p who.act)
              %agent  [who.act %caderno]  %leave  ~
      ==  ==
    ::
        %follow
      :_  this
      :~  :*  %pass  /follow/(scot %p who.act)/[id.act]
              %agent  [who.act %caderno]  %watch  /published/[id.act]
      ==  ==
    ::
        %unfollow
      =/  fol  (~(del by follows) [who.act id.act])
      :_  this(follows fol)
      :~  :*  %pass  /follow/(scot %p who.act)/[id.act]
              %agent  [who.act %caderno]  %leave  ~
          ==
          (broadcast [%follows (follows-items fol)])
      ==
    ::
        %fork
      ?~  fnb=(~(get by follows) [who.act id.act])  `this
      =/  fid=@t   (rap 3 ~[id.act '-fork-' (scot %ud counter)])
      =/  nbs2     (~(put by nbs) fid u.fnb)
      :_  this(nbs nbs2, active fid, counter +(counter))
      :~  (broadcast [%nb-list (nb-list-items nbs2)])
          (broadcast [%state fid u.fnb])
      ==
    ==
    ::  re-push the active notebook to its /published/<id> followers
    =?  cards  (~(has in published) active)
      (snoc cards (pub-fact active (~(got by nbs) active)))
    [cards this]
  ==

++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%notebook ~]
    ::  local UI subscription: seed list, active notebook, publish + follow state
    =/  nb  (need (~(get by nbs) active))
    :_  this
    :~  [%give %fact ~ %json !>((update-to-json [%nb-list (nb-list-items nbs)]))]
        [%give %fact ~ %json !>((update-to-json [%state active nb]))]
        [%give %fact ~ %json !>((update-to-json [%published published]))]
        [%give %fact ~ %json !>((update-to-json [%follows (follows-items follows)]))]
        :*  %give  %fact  ~  %json
            !>((update-to-json [%kernels (live-kernels kernels our.bowl now.bowl)]))
        ==
    ==
    ::  remote follower subscription to a published notebook
      [%published @ ~]
    =/  id=@t  i.t.path
    ?.  (~(has in published) id)
      ~|(%caderno-not-published !!)
    :_  this
    ~[[%give %fact ~ %json !>((update-to-json [%state id (~(got by nbs) id)]))]]
    ::  remote lookup subscription: serve (and live-update) the published catalog
      [%published-list ~]
    :_  this
    ~[[%give %fact ~ %json !>((update-to-json [%published-list (published-catalog published nbs)]))]]
  ==

++  on-leave  on-leave:def

++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %notebook ~]
    =/  nb  (need (~(get by nbs) active))
    =/  res=json
      :-  %o
      %-  ~(gas by *(map @t json))
      ~[['id' [%s active]] ['nb' (notebook-to-json nb)]]
    ``[%json !>(res)]
      [%x %log-status ~]
    =/  all-desks  .^((set desk) %cd (en-beam [[our.bowl %$ [%da now.bowl]] /]))
    ``[%json !>([%b (~(has in all-desks) %caderno-log)])]
      [%x %agents ~]
    ::  Every running gall agent across all desks. The UI probes each with the
    ::  shoe /x/sole/sessions scry (over HTTP, where eyre turns an absent path
    ::  into a clean 404) to find candidate kernels; %ge is a gall enumeration
    ::  scry, not reachable from the browser, so it must be surfaced here. An
    ::  in-agent .^ probe is not viable: a scry into a non-shoe agent's absent
    ::  path bails uncatchably (mule can't guard it). Suspended/unloadable desks
    ::  are skipped via mule (%ge/%cd are vane scries and always resolve).
    =/  names=(list @t)  (sort ~(tap in (running-agents our.bowl now.bowl)) aor)
    ``[%json !>(`json`[%a (turn names |=(d=@t [%s d]))])]
      [%x %kernels ~]
    ::  Shoe kernels: agents last seen to answer /x/sole/sessions, minus any
    ::  that are no longer running.
    ::
    ::  Shoe-ness cannot be determined here.  A %gx scry into an agent that
    ::  does not answer the path blocks, and a block is not catchable by mule
    ::  -- it bails with %need through the whole peek.  So the UI probes over
    ::  HTTP, where eyre turns the block into a 404, and pokes the result back
    ::  with %set-kernels.  That sweep costs one request per running agent, so
    ::  it should happen once and not on every page load; this is the cache.
    ::
    ::  Liveness is cheap and is not cached: %ge and %cd are vane scries and
    ::  always resolve, so a kernel that has since been stopped drops out here
    ::  without needing another sweep.
    ``[%json !>(`json`[%a (turn (live-kernels kernels our.bowl now.bowl) |=(k=@t [%s k]))])]
      [%x %kelvins ~]
    =/  hoon-kel  +>:..add
    =/  arvo-kel  arvo.arvo
    =/  zuse-kel  zuse.zuse
    =/  eh  (mule |.(.^(hart:eyre %e /[(scot %p our.bowl)]/host/[(scot %da now.bowl)])))
    =/  port=@ud
      ?:  ?=(%& -.eh)
        ?~  q.p.eh  80
        u.q.p.eh
      80
    ::  real desk commit hashes (mule-guarded; %$ if unreadable)
    =/  hash
      |=  =desk
      ^-  @t
      =/  h  (mule |.(.^(@uv %cz /(scot %p our.bowl)/[desk]/(scot %da now.bowl))))
      ?:(?=(%| -.h) '' (scot %uv p.h))
    =/  kels=json
      :-  %o
      %-  ~(gas by *(map @t json))
      :~  ['hoon' [%n (scot %ud hoon-kel)]]
          ['arvo' [%n (scot %ud arvo-kel)]]
          ['zuse' [%n (scot %ud zuse-kel)]]
          ['nock' [%n '4']]
          ['port' (numb:enjs:format port)]
          ['caderno_hash' [%s (hash %caderno)]]
          ['base_hash' [%s (hash %base)]]
      ==
    ``[%json !>(kels)]
  ==

++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%lookup @ ~]
    ::  a ship's published catalog (from %lookup); relay it to our UI
    =/  who=@p  (slav %p i.t.wire)
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign  `this
      ::  surface the failure to the UI as an empty catalog (so the lookup view
      ::  shows "unreachable" instead of hanging), and slog for the operator.
      %-  (slog leaf+"caderno: lookup ~{(scow %p who)} failed" u.p.sign)
      :_  this
      ~[(broadcast [%lookup who ~])]
        %kick  `this
        %fact
      ?.  =(%json p.cage.sign)  `this
      =/  try  (mule |.((json-to-catalog !<(json q.cage.sign))))
      ?:  ?=(%| -.try)  `this
      :_  this
      ~[(broadcast [%lookup who p.try])]
    ==
      [%follow @ @ ~]
    ::  updates from a remote notebook we follow; store a read-only mirror
    =/  who=@p  (slav %p i.t.wire)
    =/  id=@t   i.t.t.wire
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: follow ~{(scow %p who)}/{(trip id)} failed" u.p.sign)
      =/  fol  (~(del by follows) [who id])
      :_  this(follows fol)
      ~[(broadcast [%follows (follows-items fol)])]
        %kick
      ::  publisher dropped us (unpublished or gone); forget the mirror
      =/  fol  (~(del by follows) [who id])
      :_  this(follows fol)
      ~[(broadcast [%follows (follows-items fol)])]
        %fact
      ?.  =(%json p.cage.sign)  `this
      =/  try  (mule |.((json-to-state !<(json q.cage.sign))))
      ?:  ?=(%| -.try)
        %-  (slog leaf+"caderno: bad follow fact" p.try)
        `this
      =/  nb  +.p.try
      =/  fol  (~(put by follows) [who id] nb)
      :_  this(follows fol)
      ~[(broadcast [%follows (follows-items fol)])]
    ==
      [%caderno %session @ ~]
    =/  ses=@ta  i.t.t.wire
    =/  found    (session-by-ses ksessions ses)
    ::  a sign for a session we no longer track -- e.g. the kick that follows
    ::  a leave we sent during a reset -- has nothing left to update
    ?~  found  `this
    =/  nid=@t             id.u.found
    =/  ks=kernel-session  ks.u.found
    ::  Whether this session's notebook is the one on screen.  %cell-output
    ::  and %cell-status carry no notebook id, so the UI applies them to
    ::  whatever it is showing; a background notebook's results are recorded
    ::  in state but not broadcast.  Switching to it re-sends its full %state,
    ::  outputs included, so nothing is lost.
    =/  vis=?  =(nid active)
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: shoe session failed" u.p.sign)
      :_  this(ksessions (~(del by ksessions) nid))
      ?.  vis  ~
      ?~  pending.ks  ~
      ~[(broadcast [%cell-status id.u.pending.ks %error])]
        %kick
      ::  the kernel dropped us; fail any cell that was waiting on it rather
      ::  than leaving it %running forever
      :_  this(ksessions (~(del by ksessions) nid))
      ?.  vis  ~
      ?~  pending.ks  ~
      ~[(broadcast [%cell-status id.u.pending.ks %error])]
        %fact
      ?.  =(p.cage.sign %sole-effect)  `this
      =/  effects  (flatten-effects !<(sole-effect q.cage.sign))
      =/  cd=(list card)  ~
      =/  new-ks=kernel-session  ks
      =/  new-nb=notebook  (need (~(get by nbs) nid))
      ::  a %run-all dispatches the next queued cell from here, so exec-counts
      ::  are handed out inside this loop
      =/  ct=@ud  counter
      |-
      ?~  effects
        ::  shoe output lands here (async), not in on-poke, so the on-poke
        ::  follower re-push misses it — push explicitly if nid is published.
        =?  cd  (~(has in published) nid)
          (snoc cd (pub-fact nid new-nb))
        :_  %=  this
              ksessions  (~(put by ksessions) nid new-ks)
              nbs        (~(put by nbs) nid new-nb)
              counter    ct
            ==
        cd
      =/  efx  i.effects
      ?+  -.efx  $(effects t.effects)
          %txt
        %=  $
          effects  t.effects
          new-ks   new-ks(accum (snoc accum.new-ks (crip p.efx)))
        ==
          %pro
        ::  ready=%.n: initial %pro from shoe subscribe; session is now live
        ?:  =(%.n ready.new-ks)
          ?~  pending.new-ks
            $(effects t.effects, new-ks new-ks(ready %.y))
          ::  queued command waiting — dispatch it now
          =/  [cid=cell-id src=@t]  u.pending.new-ks
          =/  eval=card
            :*  %pass  (eval-wire ses.new-ks)  %agent
                [our.bowl agent.new-ks]
                %poke  %eval-command
                !>([ses.new-ks (trip src)])
            ==
          %=  $
            effects  t.effects
            new-ks   new-ks(ready %.y)
            cd       (weld cd ~[eval])
          ==
        ::  ready=%.y: %pro signals %eval-command completion
        ?~  pending.new-ks
          $(effects t.effects)
        =/  [cid=cell-id src=@t]  u.pending.new-ks
        ::  join accumulated %txt lines with newlines, not run together --
        ::  `zing` alone concatenates the tapes with no separator, so a
        ::  multi-line shoe-kernel output (e.g. aviary's %trace) collapsed
        ::  into one run-on line in the cell's output text.
        =/  joined
          =/  lines=(list tape)  (turn accum.new-ks trip)
          %-  crip
          |-  ^-  tape
          ?~  lines  ""
          ?~  t.lines  i.lines
          (weld i.lines (weld "\0a" $(lines t.lines)))
        ::  detect Forth error: first accumulated line starts with "! "
        =/  out
          ?~  accum.new-ks  [%text '']
          =/  ht  (trip i.accum.new-ks)
          ?:  &(?=(^ ht) =('!' i.ht) ?=(^ t.ht) =(' ' i.t.ht))
            [%error 'ForthError' joined]
          [%text joined]
        =/  c  (find-cell cid cells.new-nb)
        =/  exec-ct  ?~(c 0 ?~(exec-count.u.c 0 u.exec-count.u.c))
        =/  upd-nb
          ?~  c  new-nb
          new-nb(cells (replace-cell cid u.c(outputs [out ~]) cells.new-nb))
        =/  new-cd=(list card)
          ?.  vis  ~
          :~  (broadcast [%cell-output cid out exec-ct])
              (broadcast [%cell-status cid %done])
          ==
        ::  %run-all: hand the next queued cell to the same session.  Doing it
        ::  here, on the finished cell's %pro, is what serialises the run --
        ::  each cell sees the subject the previous one left behind.
        ?~  queue.new-ks
          %=  $
            effects  t.effects
            new-ks   new-ks(pending ~, accum ~)
            new-nb   upd-nb
            cd       (weld cd new-cd)
          ==
        =/  nxt      i.queue.new-ks
        =/  next-ct  +(ct)
        =/  nxt-nb
          =/  qc  (find-cell id.nxt cells.upd-nb)
          ?~  qc  upd-nb
          upd-nb(cells (replace-cell id.nxt u.qc(exec-count `next-ct) cells.upd-nb))
        =/  nxt-cd=(list card)
          %+  weld
            ^-  (list card)
            ?.  vis  ~
            ~[(broadcast [%cell-status id.nxt %running])]
          ^-  (list card)
          :~  :*  %pass  (eval-wire ses.new-ks)  %agent
                  [our.bowl agent.new-ks]
                  %poke  %eval-command
                  !>([ses.new-ks (trip src.nxt)])
              ==
          ==
        %=  $
          effects  t.effects
          new-ks   new-ks(pending `nxt, queue t.queue.new-ks, accum ~)
          new-nb   nxt-nb
          ct       next-ct
          cd       :(weld cd new-cd nxt-cd)
        ==
      ==
    ==
      [%caderno %eval @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: eval failed" u.p.sign)
      `this
    ==
      [%caderno %hood *]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: hood poke failed" u.p.sign)
      `this
    ==
  ==

++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
      [%caderno %clay ~]
    `this
  ==

++  on-fail   on-fail:def
--
