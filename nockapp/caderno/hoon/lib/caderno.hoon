::  caderno.hoon: the notebook model, ported from the Urbit desk.
::
::  Types follow desk/sur/caderno.hoon; the evaluator and JSON codecs
::  follow desk/app/caderno.hoon. Dropped from the Urbit version: the
::  shoe/sole remote-kernel path (no Gall agents to delegate to), the
::  publish/follow actions (no Ames), and the Clay log actions. What
::  remains is the notebook itself.
::
/+  *json
|%
+$  cell-id    @ud
+$  cell-type  ?(%code %markdown)
::
+$  output
  $%  [%text data=@t]
      [%error ename=@t evalue=@t]
  ==
::
+$  cell
  $:  id=cell-id
      type=cell-type
      source=@t
      outputs=(list output)
      exec-count=(unit @ud)
  ==
::
+$  notebook
  $:  cells=(list cell)
      kernel=@tas
      title=@t
  ==
::
::  $store: everything the kernel keeps. `subject` is the accumulated
::  Hoon subject; it is dropped on upgrade, since a stored vase carries
::  types from the old kernel.
::
+$  store
  $:  nbs=(map @t notebook)
      active=@t
      counter=@ud
      subject=(unit vase)
  ==
::
+$  action
  $%  [%run-cell id=cell-id]
      [%run-all ~]
      [%insert-cell after=(unit cell-id) type=cell-type]
      [%delete-cell id=cell-id]
      [%update-source id=cell-id src=@t]
      [%reset-subject ~]
      [%set-cell-type id=cell-id type=cell-type]
      [%set-title title=@t]
      [%new-notebook ~]
      [%switch-notebook id=@t]
      [%delete-notebook id=@t]
  ==
::
::  nbformat: notebook schema version, stamped into every serialized
::  notebook. Bump when the shape changes; readers gate on it.
::
++  nbformat  1
::
::::  evaluation
::
::  +fresh-subject: a vase of this library's compilation context.
::
::    Note this is `!>(.)` and not the Urbit desk's `!>(..add)`. The
::    latter climbs to the chapter core containing +add, which sees only
::    earlier chapters of hoon.hoon -- +sort and +turn are out of scope
::    under it. `.` captures the whole stdlib.
::
++  fresh-subject  ^-(vase !>(.))
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
::  +eval-hoon: evaluate source against a subject.
::
::    On success the result is slopped onto the front of the subject, so
::    cell N+1 reaches cell N's value at `-`. On failure the subject is
::    returned untouched.
::
++  eval-hoon
  |=  [src=@t subj=vase]
  ^-  [out=output new=vase]
  =/  parsed  (mule |.((ream src)))
  ?:  ?=(%| -.parsed)
    [[%error 'ParseError' (tang-to-cord p.parsed)] subj]
  =/  evaled  (mule |.((slap subj p.parsed)))
  ?:  ?=(%| -.evaled)
    [[%error 'EvalError' (tang-to-cord p.evaled)] subj]
  [[%text (crip ~(ram re (sell p.evaled)))] (slop p.evaled subj)]
::
::::  cell list operations
::
++  find-cell
  |=  [id=cell-id cs=(list cell)]
  ^-  (unit cell)
  ?~  cs  ~
  ?:  =(id id.i.cs)  `i.cs
  $(cs t.cs)
::
++  replace-cell
  |=  [id=cell-id c=cell cs=(list cell)]
  ^-  (list cell)
  ?~  cs  ~
  ?:  =(id id.i.cs)  [c t.cs]
  [i.cs $(cs t.cs)]
::
++  remove-cell
  |=  [id=cell-id cs=(list cell)]
  ^-  (list cell)
  ?~  cs  ~
  ?:  =(id id.i.cs)  t.cs
  [i.cs $(cs t.cs)]
::
++  insert-after-cell
  |=  [after=cell-id c=cell cs=(list cell)]
  ^-  (list cell)
  ?~  cs  ~[c]
  ?:  =(after id.i.cs)  [i.cs c t.cs]
  [i.cs $(cs t.cs)]
::
::::  defaults
::
++  blank-notebook
  |=  title=@t
  ^-  notebook
  :*  cells=~[[id=1 type=%code source='(add 2 2)' outputs=~ exec-count=~]]
      kernel=%hoon
      title=title
  ==
::
::  +ensure-init: on a fresh kernel the store is a bunt, so give it a
::  notebook to be active in.
::
++  ensure-init
  |=  s=store
  ^-  store
  ?.  =(~ nbs.s)  s
  %=  s
    nbs      (~(put by *(map @t notebook)) 'main' (blank-notebook 'Untitled'))
    active   'main'
    counter  100
  ==
::
::::  actions
::
++  apply
  |=  [act=action s=store]
  ^-  store
  =.  s  (ensure-init s)
  =/  nb=notebook  (~(gut by nbs.s) active.s (blank-notebook 'Untitled'))
  ?-    -.act
      %run-cell
    =/  c  (find-cell id.act cells.nb)
    ?~  c  s
    ?.  =(%code type.u.c)  s
    =/  subj=vase  ?~(subject.s fresh-subject u.subject.s)
    =/  new-count  +(counter.s)
    =/  res  (eval-hoon source.u.c subj)
    =/  new-cell  u.c(outputs ~[out.res], exec-count `new-count)
    %=  s
      nbs      (~(put by nbs.s) active.s nb(cells (replace-cell id.act new-cell cells.nb)))
      counter  new-count
      subject  `new.res
    ==
  ::
      %run-all
    ::  Run every code cell top to bottom against a fresh subject, so
    ::  later cells can reference earlier results.
    =/  cs=(list cell)  cells.nb
    =/  todo=(list cell)  (skim cells.nb |=(c=cell =(%code type.c)))
    =/  ct=@ud   counter.s
    =/  subj     fresh-subject
    |-
    ?~  todo
      %=  s
        nbs      (~(put by nbs.s) active.s nb(cells cs))
        counter  ct
        subject  `subj
      ==
    =/  new-ct  +(ct)
    =/  res  (eval-hoon source.i.todo subj)
    =/  new-cell  i.todo(outputs ~[out.res], exec-count `new-ct)
    $(todo t.todo, cs (replace-cell id.i.todo new-cell cs), ct new-ct, subj new.res)
  ::
      %insert-cell
    =/  new-cell=cell
      [id=counter.s type=type.act source='' outputs=~ exec-count=~]
    =/  new-cells
      ?~  after.act  (snoc cells.nb new-cell)
      (insert-after-cell u.after.act new-cell cells.nb)
    %=  s
      nbs      (~(put by nbs.s) active.s nb(cells new-cells))
      counter  +(counter.s)
    ==
  ::
      %delete-cell
    s(nbs (~(put by nbs.s) active.s nb(cells (remove-cell id.act cells.nb))))
  ::
      %update-source
    =/  c  (find-cell id.act cells.nb)
    ?~  c  s
    =/  new-cell  u.c(source src.act)
    s(nbs (~(put by nbs.s) active.s nb(cells (replace-cell id.act new-cell cells.nb))))
  ::
      %reset-subject
    s(subject ~)
  ::
      %set-cell-type
    =/  c  (find-cell id.act cells.nb)
    ?~  c  s
    =/  new-cell  u.c(type type.act)
    s(nbs (~(put by nbs.s) active.s nb(cells (replace-cell id.act new-cell cells.nb))))
  ::
      %set-title
    s(nbs (~(put by nbs.s) active.s nb(title title.act)))
  ::
      %new-notebook
    =/  new-id  (cat 3 'nb-' (scot %ud counter.s))
    %=  s
      nbs      (~(put by nbs.s) new-id (blank-notebook 'Untitled'))
      active   new-id
      counter  +(counter.s)
      subject  ~
    ==
  ::
      %switch-notebook
    ?.  (~(has by nbs.s) id.act)  s
    s(active id.act, subject ~)
  ::
      %delete-notebook
    =/  rest  (~(del by nbs.s) id.act)
    ::  never leave the store with no notebook to be active in
    ?~  rest
      %=  s
        nbs      (~(put by *(map @t notebook)) 'main' (blank-notebook 'Untitled'))
        active   'main'
        subject  ~
      ==
    ?.  =(id.act active.s)  s(nbs rest)
    s(nbs rest, active p.n.rest, subject ~)
  ==
::
::::  JSON encoding
::
::  +jnum: @ud -> JSON number. +scot on %ud emits dot separators
::  ('1.000'), which is not valid JSON, so strip them. The Urbit desk
::  emits the raw +scot output and relies on reader tolerance; here the
::  wire format is plain JSON, so fix it at the source.
::
++  jnum
  |=  n=@ud
  ^-  json
  [%n (crip (skip (trip (scot %ud n)) |=(c=@tD =('.' c))))]
::
++  jobj
  |=  l=(list [@t json])
  ^-  json
  [%o (~(gas by *(map @t json)) l)]
::
++  output-to-json
  |=  out=output
  ^-  json
  ?-  -.out
    %text   (jobj ~[['text' [%s data.out]]])
    %error  (jobj ~[['ename' [%s ename.out]] ['evalue' [%s evalue.out]]])
  ==
::
++  cell-to-json
  |=  c=cell
  ^-  json
  %-  jobj
  :~  ['id' (jnum id.c)]
      ['type' [%s (scot %tas type.c)]]
      ['source' [%s source.c]]
      ['exec_count' ?~(exec-count.c ~ (jnum u.exec-count.c))]
      ['outputs' [%a (turn outputs.c output-to-json)]]
  ==
::
++  notebook-to-json
  |=  nb=notebook
  ^-  json
  %-  jobj
  :~  ['nbformat' (jnum nbformat)]
      ['title' [%s title.nb]]
      ['kernel' [%s (scot %tas kernel.nb)]]
      ['cells' [%a (turn cells.nb cell-to-json)]]
  ==
::
::  +store-to-json: a full snapshot. The Urbit agent streams incremental
::  +$update facts over an Eyre channel; there is no such channel here,
::  so every action responds with the whole state instead. Cheap at
::  notebook scale, and it removes a class of client/server drift.
::
++  store-to-json
  |=  s=store
  ^-  json
  %-  jobj
  :~  :-  'state'
      %-  jobj
      :~  ['id' [%s active.s]]
          ['nb' (notebook-to-json (~(gut by nbs.s) active.s (blank-notebook 'Untitled')))]
      ==
      :-  'nb-list'
      :-  %a
      %+  turn  ~(tap by nbs.s)
      |=  [id=@t nb=notebook]
      (jobj ~[['id' [%s id]] ['title' [%s title.nb]]])
  ==
::
::::  JSON decoding
::
++  so-json
  |=  j=json
  ^-  @t
  ?>  ?=([%s *] j)
  p.j
::
::  +ni-json: tolerant JSON-number -> @ud. +scot on %ud emits dot
::  separators ('1.000'), so strip them before parsing.
::
++  ni-json
  |=  j=json
  ^-  @ud
  ?>  ?=([%n *] j)
  (rash (crip (skip (trip p.j) |=(c=@tD =('.' c)))) dem)
::
++  to-cell-type
  |=  t=@t
  ^-  cell-type
  ?:(=(t 'code') %code %markdown)
::
::  +json-to-action: parse {"action-name": {...}}, the same envelope the
::  Urbit desk's mar/cnb-action.hoon accepts, so the existing UI payloads
::  carry over. Returns ~ on anything unrecognized rather than crashing:
::  a bad request should be a 400, not a nacked poke.
::
++  json-to-action
  |=  j=json
  ^-  (unit action)
  ?.  ?=([%o *] j)  ~
  =/  obj  p.j
  =/  get-obj
    |=  k=@t
    ^-  (unit (map @t json))
    ?~  v=(~(get by obj) k)  ~
    ?.  ?=([%o *] u.v)  ~
    `p.u.v
  ::
  ?:  (~(has by obj) 'run-all')        `[%run-all ~]
  ?:  (~(has by obj) 'reset-subject')  `[%reset-subject ~]
  ?:  (~(has by obj) 'new-notebook')   `[%new-notebook ~]
  ::
  ?:  (~(has by obj) 'run-cell')
    ?~  m=(get-obj 'run-cell')  ~
    `[%run-cell id=(ni-json (~(got by u.m) 'id'))]
  ::
  ?:  (~(has by obj) 'insert-cell')
    ?~  m=(get-obj 'insert-cell')  ~
    =/  af  (~(get by u.m) 'after')
    :-  ~
    :+  %insert-cell
      after=?:(?=([~ %n *] af) `(ni-json u.af) ~)
    type=(to-cell-type (so-json (~(got by u.m) 'type')))
  ::
  ?:  (~(has by obj) 'delete-cell')
    ?~  m=(get-obj 'delete-cell')  ~
    `[%delete-cell id=(ni-json (~(got by u.m) 'id'))]
  ::
  ?:  (~(has by obj) 'update-source')
    ?~  m=(get-obj 'update-source')  ~
    :-  ~
    :+  %update-source
      id=(ni-json (~(got by u.m) 'id'))
    src=(so-json (~(got by u.m) 'src'))
  ::
  ?:  (~(has by obj) 'set-cell-type')
    ?~  m=(get-obj 'set-cell-type')  ~
    :-  ~
    :+  %set-cell-type
      id=(ni-json (~(got by u.m) 'id'))
    type=(to-cell-type (so-json (~(got by u.m) 'type')))
  ::
  ?:  (~(has by obj) 'set-title')
    ?~  m=(get-obj 'set-title')  ~
    `[%set-title title=(so-json (~(got by u.m) 'title'))]
  ::
  ?:  (~(has by obj) 'switch-notebook')
    ?~  m=(get-obj 'switch-notebook')  ~
    `[%switch-notebook id=(so-json (~(got by u.m) 'id'))]
  ::
  ?:  (~(has by obj) 'delete-notebook')
    ?~  m=(get-obj 'delete-notebook')  ~
    `[%delete-notebook id=(so-json (~(got by u.m) 'id'))]
  ~
--
