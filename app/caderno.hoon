::  /app/caderno.hoon
::  caderno: hoon notebook (phase 0)
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
++  find-cell
  |=  [id=cell-id cs=(list cell)]
  ^-  (unit cell)
  |-
  ?~  cs  ~
  ?.  =(id id.i.cs)
    $(cs t.cs)
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
  =/  s  !<(state-0 old)
  `this(nb nb.s, counter counter.s)
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
      =/  out  (eval-source source.u.c)
      =/  new-cell  u.c(outputs [out ~], exec-count `new-count)
      =/  new-nb  nb(cells (replace-cell id new-cell cells.nb))
      =/  status
        ?-  -.out
          %text   %done
          %error  %error
        ==
      :_  this(nb new-nb, counter new-count)
      :~  (broadcast [%cell-status id %running])
          (broadcast [%cell-output id out])
          (broadcast [%cell-status id status])
      ==
    ::
        %run-all
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
      =/  status
        ?-  -.out
          %text   %done
          %error  %error
        ==
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
++  on-peek   on-peek:def
++  on-agent  on-agent:def
++  on-arvo   on-arvo:def
++  on-fail   on-fail:def
--
