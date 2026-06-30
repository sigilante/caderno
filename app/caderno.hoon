::  /app/caderno.hoon
::  caderno: hoon notebook (phase 1)
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
+$  versioned-state  $%([%0 state-0] [%1 state-1])
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
++  tang-to-cord
  |=  t=tang
  ^-  @t
  (crip (zing (turn t |=(=tank ~(ram re tank)))))
++  eval-source
  |=  src=@t
  ^-  output
  =/  std  !>(..add)
  =/  parsed  (mule |.((ream src)))
  ?:  ?=(%| -.parsed)
    [%error 'ParseError' (tang-to-cord p.parsed)]
  =/  evaled  (mule |.((slap std p.parsed)))
  ?:  ?=(%| -.evaled)
    [%error 'EvalError' (tang-to-cord p.evaled)]
  [%text (crip ~(ram re (sell p.evaled)))]
++  broadcast
  |=  upd=update
  ^-  card
  [%give %fact [[%notebook ~] ~] %noun !>(upd)]
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
=|  state-1
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
  `this(nb blank, ksession ~, counter 0)
++  on-save  !>(`versioned-state`[%1 nb ksession counter])
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  try1  (mule |.(!<(state-1 old)))
  ?:  ?=(%& -.try1)
    =/  s  p.try1
    `this(nb nb.s, ksession ksession.s, counter counter.s)
  =/  try0  (mule |.(!<(state-0 old)))
  ?:  ?=(%& -.try0)
    =/  s  p.try0
    `this(nb nb.s, ksession ~, counter counter.s)
  `this(nb [~ %hoon 'untitled'], ksession ~, counter 0)
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
      ::  hoon kernel: direct eval
      ?:  =(%hoon kernel.nb)
        =/  out  (eval-source source.u.c)
        =/  new-cell  u.c(outputs [out ~], exec-count `new-count)
        =/  new-nb  nb(cells (replace-cell id new-cell cells.nb))
        =/  status  ?-(-.out %text %done, %error %error)
        :_  this(nb new-nb, counter new-count)
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
      ::  run-all only works for %hoon kernel; shoe kernels are sequential/async
      =/  code-cells  (skim cells.nb |=(c=cell =(%code type.c)))
      =/  cs=(list cell)   cells.nb
      =/  cd=(list card)   ~
      =/  ct=@ud           counter
      |-
      ?~  code-cells
        :_  this(nb nb(cells cs), counter ct)
        cd
      =/  c   i.code-cells
      =/  new-ct  +(ct)
      =/  out  (eval-source source.c)
      =/  new-cell  c(outputs [out ~], exec-count `new-ct)
      =/  status  ?-(-.out %text %done, %error %error)
      =/  new-cd
        %+  weld  cd
        :~  (broadcast [%cell-status id.c %running])
            (broadcast [%cell-output id.c out])
            (broadcast [%cell-status id.c status])
        ==
      $(code-cells t.code-cells, cs (replace-cell id.c new-cell cs), cd new-cd, ct new-ct)
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
      =/  new-nb  nb(cells (snoc cells.nb new-cell))
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
