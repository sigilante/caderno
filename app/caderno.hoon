::  /app/caderno.hoon
::  caderno: hoon notebook (phase 0)
::
::  Phase 0 limitations (see docs/ROADMAP.md):
::  - single in-memory notebook; no Clay persistence
::  - evaluation via ++slap/++ream against !>(..add); no %shoe sessions yet
::  - no cross-cell subject accumulation; each cell evaluates against the
::    base standard library subject independently
::  - output types: %text (pretty-printed) and %error only
::
/-  *caderno
/+  default-agent, dbug
|%
+$  versioned-state  $%([%0 state-0])
+$  state-0
  $:  nb=notebook
      counter=@ud
  ==
+$  card  card:agent:gall
--
=|  state-0
=*  state  -
^-  agent:gall
%-  agent:dbug
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
++  on-init
  ^-  (quip card _this)
  =/  blank  ^-  notebook
    :*  cells=~
        kernel=%hoon
        title='untitled'
    ==
  `this(nb blank, counter 0)
++  on-save   !>(state)
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  `this(+<- !<(state-0 old))
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %caderno-action
    =/  act  !<(action vase)
    ?-  -.act
      %run-cell      (do-run-cell id.act)
      %run-all       (do-run-all ~)
      %insert-cell   (do-insert-cell after.act type.act)
      %delete-cell   (do-delete-cell id.act)
      %update-source  (do-update-source id.act src.act)
    ==
  ==
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%notebook ~]
    :_  this
    ~[[%give %fact ~ %noun !>(`update`[%state nb])]]
  ==
++  on-leave   on-leave:def
++  on-peek    on-peek:def
++  on-agent   on-agent:def
++  on-arvo    on-arvo:def
++  on-fail    on-fail:def
::
::  helpers
++  find-cell
  |=  id=cell-id
  ^-  (unit cell)
  |-
  ?~  cells.nb  ~
  ?.  =(id id.i.cells.nb)
    $(cells.nb t.cells.nb)
  `i.cells.nb
++  replace-cell
  |=  [id=cell-id new=cell]
  ^-  (list cell)
  (turn cells.nb |=(c=cell ?:(=(id id.c) new c)))
++  tang-to-cord
  |=  t=tang
  ^-  @t
  (crip (of-wall (zing (turn t (cury wash [0 80])))))
++  eval-source
  ::  evaluate hoon source text against the standard library subject
  ::  A1: any parse failure (including incomplete expressions) → %error
  |=  src=@t
  ^-  output
  ::  capture the standard library subject at evaluation time
  =/  std  !>(..add)
  ::  parse
  =/  parsed  (mule |.((ream src)))
  ?:  ?=(%| -.parsed)
    [%error 'ParseError' (tang-to-cord p.parsed)]
  ::  evaluate
  =/  evaled  (mule |.((slap std p.parsed)))
  ?:  ?=(%| -.evaled)
    [%error 'EvalError' (tang-to-cord p.evaled)]
  ::  pretty-print result
  ::  TODO: verify ~(sell ut p.p.evaled) q.p.evaled works on ship; adjust if needed
  =/  result-tank  (~(sell ut p.p.evaled) q.p.evaled)
  [%text (crip ~(ram re result-tank))]
++  broadcast
  |=  upd=update
  ^-  card
  [%give %fact [/notebook]~ %noun !>(upd)]
::
::  action handlers
++  do-run-cell
  |=  id=cell-id
  ^-  (quip card _this)
  =/  c  (find-cell id)
  ?~  c  `this
  ?.  =(%code type.u.c)  `this
  =/  new-count  +(counter)
  =/  out  (eval-source source.u.c)
  =/  new-cell  u.c(outputs [out ~], exec-count `new-count)
  =/  new-nb  nb(cells (replace-cell id new-cell))
  =/  status  ?-  -.out
    %text   %done
    %error  %error
  ==
  :_  this(nb new-nb, counter new-count)
  :~  (broadcast [%cell-status id %running])
      (broadcast [%cell-output id out])
      (broadcast [%cell-status id status])
  ==
++  do-run-all
  |=  ~
  ^-  (quip card _this)
  =/  code-ids
    %+  turn
      (skim cells.nb |=(c=cell =(%code type.c)))
    |=(c=cell id.c)
  |-
  ?~  code-ids  `this
  =^  cards-1=(list card)  this  (do-run-cell i.code-ids)
  =^  cards-2=(list card)  this  $(code-ids t.code-ids)
  [(weld cards-1 cards-2) this]
++  do-insert-cell
  |=  [after=(unit cell-id) type=cell-type]
  ^-  (quip card _this)
  =/  new-id  counter
  =/  new-cell  ^-  cell
    :*  id=new-id
        type=type
        source=''
        outputs=~
        exec-count=~
    ==
  ::  phase 0: always append; insertion position TODO
  =/  new-nb  nb(cells (snoc cells.nb new-cell))
  :_  this(nb new-nb, counter +(counter))
  ~[(broadcast [%cell-added new-cell])]
++  do-delete-cell
  |=  id=cell-id
  ^-  (quip card _this)
  =/  new-nb  nb(cells (skip cells.nb |=(c=cell =(id id.c))))
  :_  this(nb new-nb)
  ~[(broadcast [%cell-deleted id])]
++  do-update-source
  |=  [id=cell-id src=@t]
  ^-  (quip card _this)
  =/  c  (find-cell id)
  ?~  c  `this
  =/  new-nb  nb(cells (replace-cell id u.c(source src)))
  `this(nb new-nb)
--
