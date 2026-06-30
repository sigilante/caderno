::  /app/caderno.hoon
::  caderno: hoon notebook (phase 2 — persistent subject, correct insert)
::
/-  *caderno, *sole
/+  default-agent, dbug
|%
+$  state-0  $:  nb=notebook  counter=@ud  ==
+$  state-1
  $:  nb=notebook
      ksession=(unit kernel-session)
      counter=@ud
  ==
::  state-2 adds a per-notebook Hoon evaluation subject.
::  After each successful Hoon cell run, the result vase is slop'd onto the
::  subject so successive cells can reference prior results via wing paths
::  (e.g. `-` = last result, `+.-` = result before that).  The stdlib
::  remains accessible because it lives in the tail.  On every on-load we
::  reset to !>(..add) so stale vases from prior kernel versions don't crash.
+$  state-2
  $:  nb=notebook
      ksession=(unit kernel-session)
      counter=@ud
      hoon-subject=vase
  ==
+$  versioned-state  $%([%0 state-0] [%1 state-1] [%2 state-2])
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
  !>(..add)

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

++  update-to-json
  |=  upd=update
  ^-  json
  ?-  -.upd
      %state
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['state' [%o (~(gas by *(map @t json)) ~[['nb' (notebook-to-json nb.upd)]])]]]
      %cell-output
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-output' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]] ['out' (output-to-json out.upd)]])]]]
      %cell-status
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-status' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]] ['status' [%s (scot %tas status.upd)]]])]]]
      %cell-added
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-added' [%o (~(gas by *(map @t json)) ~[['c' (cell-to-json c.upd)]])]]]
      %cell-deleted
    :-  %o
    %-  ~(gas by *(map @t json))
    ~[['cell-deleted' [%o (~(gas by *(map @t json)) ~[['id' [%n (scot %ud id.upd)]]])]]]
  ==

++  broadcast
  |=  upd=update
  ^-  card
  [%give %fact [[%notebook ~] ~] %json !>((update-to-json upd))]

++  accum-to-output
  |=  lines=(list @t)
  ^-  output
  [%text (crip (zing (turn lines trip)))]

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

++  notebook-to-json
  |=  nb=notebook
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  :~  ['title' [%s title.nb]]
      ['kernel' [%s (scot %tas kernel.nb)]]
      ['cells' [%a (turn cells.nb cell-to-json)]]
  ==
--

=|  state-2
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
  `this(nb blank, ksession ~, counter 0, hoon-subject fresh-subject)

++  on-save  !>(`versioned-state`[%2 nb ksession counter hoon-subject])

++  on-load
  |=  old=vase
  ^-  (quip card _this)
  ::  Always reset hoon-subject on load: stored vases may be stale after
  ::  kernel upgrades, and a reset is safer than a crash.
  =/  try2  (mule |.(!<(state-2 old)))
  ?:  ?=(%& -.try2)
    =/  s  p.try2
    `this(nb nb.s, ksession ksession.s, counter counter.s, hoon-subject fresh-subject)
  =/  try1  (mule |.(!<(state-1 old)))
  ?:  ?=(%& -.try1)
    =/  s  p.try1
    `this(nb nb.s, ksession ksession.s, counter counter.s, hoon-subject fresh-subject)
  =/  try0  (mule |.(!<(state-0 old)))
  ?:  ?=(%& -.try0)
    =/  s  p.try0
    `this(nb nb.s, ksession ~, counter counter.s, hoon-subject fresh-subject)
  `this(nb [~ %hoon 'untitled'], ksession ~, counter 0, hoon-subject fresh-subject)

++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %caderno-action
    =/  act  !<(action vase)
    ?-  -.act
        %run-cell
      =/  id  id.act
      =/  c  (find-cell id cells.nb)
      ?~  c  `this
      ?.  =(%code type.u.c)  `this
      =/  new-count  +(counter)
      ::  hoon kernel: evaluate against accumulated subject
      ?:  =(%hoon kernel.nb)
        =/  [out new-subj]  (eval-hoon source.u.c hoon-subject)
        =/  new-cell  u.c(outputs [out ~], exec-count `new-count)
        =/  new-nb  nb(cells (replace-cell id new-cell cells.nb))
        =/  status  ?-(-.out %text %done, %error %error)
        :_  this(nb new-nb, counter new-count, hoon-subject new-subj)
        :~  (broadcast [%cell-status id %running])
            (broadcast [%cell-output id out])
            (broadcast [%cell-status id status])
        ==
      ::  shoe kernel: delegate to session
      =/  src  source.u.c
      =/  ses  `@ta`%caderno
      =/  old-own  ?~(ksession 0 own.u.ksession)
      =/  old-his  ?~(ksession 0 his.u.ksession)
      =/  new-ks  ^-  kernel-session
        :*  agent=kernel.nb
            ses=ses
            own=+(old-own)
            his=old-his
            pending=`id
            accum=~
        ==
      =/  sid  ^-  sole-id  [our.bowl ses]
      =/  buf=(list @c)  (rip 3 src)
      =/  chg=sole-change
        [ler=[own=old-his his=old-own] haw=`@uvH`0 ted=[%set p=buf]]
      =/  det=card
        :*  %pass  /caderno/det  %agent
            [our.bowl kernel.nb]
            %poke  %sole-action
            !>(`sole-action`[id=sid dat=[%det chg]])
        ==
      =/  ret=card
        :*  %pass  /caderno/ret  %agent
            [our.bowl kernel.nb]
            %poke  %sole-action
            !>(`sole-action`[id=sid dat=[%ret ~]])
        ==
      =/  timer=card
        [%pass /caderno/timer %arvo %b %wait (add now.bowl ~s2)]
      ?~  ksession
        =/  watch=card
          :*  %pass  /caderno/session  %agent
              [our.bowl kernel.nb]
              %watch  /sole/(scot %p our.bowl)/caderno
          ==
        :_  this(nb nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb)), ksession `new-ks, counter new-count)
        :~  (broadcast [%cell-status id %running])
            watch
            det
            ret
            timer
        ==
      :_  this(nb nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb)), ksession `new-ks, counter new-count)
      :~  (broadcast [%cell-status id %running])
          det
          ret
          timer
      ==
    ::
        %run-all
      ::  Runs all code cells top-to-bottom with a fresh subject.
      ::  Each cell's result is accumulated so later cells can reference
      ::  earlier results.  Shoe kernels are async and not supported here.
      =/  code-cells  (skim cells.nb |=(c=cell =(%code type.c)))
      =/  cs=(list cell)   cells.nb
      =/  cd=(list card)   ~
      =/  ct=@ud           counter
      =/  subj=vase        fresh-subject
      |-
      ?~  code-cells
        :_  this(nb nb(cells cs), counter ct, hoon-subject subj)
        cd
      =/  c   i.code-cells
      =/  new-ct  +(ct)
      =/  [out new-subj]
        ?:  =(%hoon kernel.nb)
          (eval-hoon source.c subj)
        ::  non-hoon kernel: run-all not supported; emit a placeholder error
        [[%error 'KernelError' 'run-all unsupported for shoe kernels'] subj]
      =/  new-cell  c(outputs [out ~], exec-count `new-ct)
      =/  status  ?-(-.out %text %done, %error %error)
      =/  new-cd
        %+  weld  cd
        :~  (broadcast [%cell-status id.c %running])
            (broadcast [%cell-output id.c out])
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
      :_  this(nb new-nb, counter +(counter))
      ~[(broadcast [%cell-added new-cell])]
    ::
        %delete-cell
      =/  id  id.act
      =/  new-nb  nb(cells (skip cells.nb |=(c=cell =(id id.c))))
      :_  this(nb new-nb)
      ~[(broadcast [%cell-deleted id])]
    ::
        %update-source
      =/  id  id.act
      =/  c  (find-cell id cells.nb)
      ?~  c  `this
      =/  new-nb  nb(cells (replace-cell id u.c(source src.act) cells.nb))
      `this(nb new-nb)
    ::
        %set-kernel
      `this(nb nb(kernel kernel.act))
    ::
        %reset-subject
      ::  Clears the accumulated Hoon evaluation subject back to !>(..add).
      ::  Use this when prior cell results have polluted the environment.
      `this(hoon-subject fresh-subject)
    ==
  ==

++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%notebook ~]
    :_  this
    ~[[%give %fact ~ %json !>((update-to-json [%state nb]))]]
  ==

++  on-leave  on-leave:def

++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %notebook ~]
    ``[%json !>((notebook-to-json nb))]
  ==

++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  (on-agent:def wire sign)
      [%caderno %session ~]
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: shoe session failed" u.p.sign)
      `this(ksession ~)
        %kick
      `this(ksession ~)
        %fact
      ?.  =(p.cage.sign %sole-effect)  `this
      ?~  ksession  `this
      =/  ks  u.ksession
      =/  effects  (flatten-effects !<(sole-effect q.cage.sign))
      =/  cd=(list card)  ~
      =/  new-ks=kernel-session  ks
      =/  new-nb=notebook  nb
      |-
      ?~  effects
        :_  this(ksession `new-ks, nb new-nb)
        cd
      =/  efx  i.effects
      ?+  -.efx  $(effects t.effects)
          %txt
        %=  $
          effects  t.effects
          new-ks   new-ks(accum (snoc accum.new-ks (crip p.efx)))
        ==
          %pro
        ?~  pending.new-ks
          $(effects t.effects)
        =/  cid  u.pending.new-ks
        =/  out  (accum-to-output accum.new-ks)
        =/  c  (find-cell cid cells.new-nb)
        =/  upd-nb
          ?~  c  new-nb
          new-nb(cells (replace-cell cid u.c(outputs [out ~]) cells.new-nb))
        =/  new-cd
          :~  (broadcast [%cell-output cid out])
              (broadcast [%cell-status cid %done])
          ==
        %=  $
          effects  t.effects
          new-ks   new-ks(pending ~, accum ~)
          new-nb   upd-nb
          cd       (weld cd new-cd)
        ==
          %det
        %=  $
          effects  t.effects
          new-ks   new-ks(his +(his.new-ks))
        ==
      ==
    ==
      [%caderno %det ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: det failed" u.p.sign)
      `this
    ==
      [%caderno %ret ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      %-  (slog leaf+"caderno: ret failed" u.p.sign)
      `this
    ==
  ==

++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  (on-arvo:def wire sign-arvo)
      [%caderno %timer ~]
    ?~  ksession  `this
    =/  ks  u.ksession
    ?~  pending.ks  `this
    =/  cid  u.pending.ks
    =/  out  (accum-to-output accum.ks)
    =/  c  (find-cell cid cells.nb)
    =/  new-nb
      ?~  c  nb
      nb(cells (replace-cell cid u.c(outputs [out ~]) cells.nb))
    :_  this(ksession `ks(pending ~, accum ~), nb new-nb)
    :~  (broadcast [%cell-output cid out])
        (broadcast [%cell-status cid %done])
    ==
  ==

++  on-fail   on-fail:def
--
