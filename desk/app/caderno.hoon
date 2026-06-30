::  /app/caderno.hoon
::  caderno: hoon notebook
::
/-  *caderno, *sole
/+  default-agent, dbug
|%
::  nbs maps stable @t id to notebook; active is the focused notebook id.
+$  state-4
  $:  nbs=(map @t notebook)
      active=@t
      ksession=(unit kernel-session)
      counter=@ud
      hoon-subject=vase
  ==
+$  versioned-state  $%([%4 state-4])
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

++  nb-list-items
  |=  ns=(map @t notebook)
  ^-  (list [id=@t title=@t])
  (turn ~(tap by ns) |=([id=@t nb=notebook] [id title.nb]))

++  any-key
  ::  Returns any key from a non-null map.  Used when we need to pick a
  ::  fallback notebook after deleting the active one.
  |=  ns=(map @t notebook)
  ^-  @t
  ?>  ?=(^ ns)
  p.n.ns

++  hoon-school-nbs
  ^-  (map @t notebook)
  %-  ~(gas by *(map @t notebook))
  :~
    :-  'hs-syntax'
    ^-  notebook
    :+  ^-  (list cell)
        :~
          :*  id=1  type=%markdown
              source=(crip "# 1. Hoon Syntax\0a\0aEvery Hoon expression produces a **noun**: either an **atom** (unsigned integer) or a **cell** (pair of nouns).")
              outputs=~  exec-count=~
          ==
          :*  id=2  type=%markdown
              source=(crip "## Atoms and Auras\0a\0aAtoms carry **auras** that control display format:\0a- `@ud` unsigned decimal\0a- `@ux` hexadecimal\0a- `@ub` binary\0a- `@p` ship name\0a- `@t` UTF-8 text (cord)")
              outputs=~  exec-count=~
          ==
          [3 %code '`@ub`32' ~ ~]
          [4 %code '`@ux`255' ~ ~]
          [5 %code '^-  @ux  0x1ab4' ~ ~]
          :*  id=6  type=%markdown
              source=(crip "## Cells\0a\0aCells are pairs `[a b]`. Nesting is right-associative: `[1 2 3]` = `[1 [2 3]]`.")
              outputs=~  exec-count=~
          ==
          [7 %code '[1 2]' ~ ~]
          [8 %code '[[1 2] 3]' ~ ~]
          [9 %code '[1 2 3]' ~ ~]
          :*  id=10  type=%markdown
              source=(crip "## Runes\0a\0aHoon uses two-character ASCII **runes** as keywords. Each has a tall form (newlines) and wide form (parens):\0a\0a- `:-` colhep -- build cell\0a- `%-` cenhep -- call gate\0a- `=/` tisfas -- bind name\0a- `^-` kethep -- type cast\0a- `?:` wutcol -- if/then/else")
              outputs=~  exec-count=~
          ==
          [11 %code ':-  1  2' ~ ~]
          [12 %code '(add 1 2)' ~ ~]
          [13 %code '%-  sub  [5 1]' ~ ~]
          :*  id=14  type=%markdown
              source=(crip "## Faces\0a\0a`=/  name  value  expr` binds a **face** (name) to a value in scope for `expr`.")
              outputs=~  exec-count=~
          ==
          [15 %code (crip "=/  perfect-number  28\0a(add perfect-number 10)") ~ ~]
          :*  id=16  type=%markdown
              source=(crip "## Lists\0a\0aLists are null-terminated cells. `~[1 2 3]` is sugar for `[1 [2 [3 ~]]]`.")
              outputs=~  exec-count=~
          ==
          [17 %code '~[1 2 3]' ~ ~]
          [18 %code (crip "`(list @ud)`[1 2 3 ~]") ~ ~]
          :*  id=19  type=%markdown
              source=(crip "## Branching\0a\0a`?:  condition  if-true  if-false` is Hoon's if/then/else.")
              outputs=~  exec-count=~
          ==
          [20 %code (crip "=/  x  10\0a?:  (gte x 10)\0a  'yes'\0a'no'") ~ ~]
        ==
      %hoon
    'Hoon School: 1. Syntax'
    :-  'hs-azimuth'
    ^-  notebook
    :+  ^-  (list cell)
        :~
          :*  id=1  type=%markdown
              source=(crip "# 2. Azimuth (Urbit ID)\0a\0aAzimuth is Urbit's public-key infrastructure on Ethereum. Every ship has a cryptographic identity called a **point**, displayed with the `@p` aura.")
              outputs=~  exec-count=~
          ==
          :*  id=2  type=%markdown
              source=(crip "## The Address Space\0a\0a| Rank | Size | Example |\0a|------|------|---------|\0a| Galaxy | 256 | `~zod`, `~fes` |\0a| Star | ~65K | `~marzod` |\0a| Planet | ~4B | `~sampel-palnet` |\0a| Moon | 2^64 | `~doznec-sampel` |\0a\0aThe `@p` mnemonic names come from 256 prefix + 256 suffix syllables.")
              outputs=~  exec-count=~
          ==
          [3 %code '`@p`0' ~ ~]
          [4 %code '`@p`255' ~ ~]
          [5 %code (crip "`@ud`~sampel-palnet") ~ ~]
          :*  id=6  type=%markdown
              source=(crip "## Address Arithmetic\0a\0aSince `@p` values are unsigned integers, you can do arithmetic on them. Galaxies are 0-255, stars 256-65535, planets 65536 and above.")
              outputs=~  exec-count=~
          ==
          [7 %code (crip "`@p`(add `@ud`~zod 1)") ~ ~]
          [8 %code (crip "`@p`(sub `@ud`~sampel-palnet 1)") ~ ~]
          :*  id=9  type=%markdown
              source=(crip "## Sponsors\0a\0aEvery planet is sponsored by a star; every star by a galaxy. Subtract 2^16 (65,536) from a planet to find its sponsoring star.\0a\0a> `(sein:title our now point)` works in dojo where `our` and `now` are in scope.")
              outputs=~  exec-count=~
          ==
          [10 %code (crip ":: Star sponsoring ~sampel-palnet\0a`@p`(sub `@ud`~sampel-palnet 65.536)") ~ ~]
          [11 %code (crip ":: A moon of ~sampel-palnet (add 2^32)\0a`@p`(add `@ud`~sampel-palnet 4.294.967.296)") ~ ~]
        ==
      %hoon
    'Hoon School: 2. Azimuth'
    :-  'hs-gates'
    ^-  notebook
    :+  ^-  (list cell)
        :~
          :*  id=1  type=%markdown
              source=(crip "# 3. Gates (Functions)\0a\0aA **gate** is Hoon's function. Build one with `|=` (bartis): it takes a **sample** (typed input) and produces a **product** (return value).")
              outputs=~  exec-count=~
          ==
          :*  id=2  type=%markdown
              source=(crip "## Sugar Syntax\0a\0aMany Hoon runes have short irregular equivalents:\0a\0a| Tall form | Sugar | Meaning |\0a|-----------|-------|---------|\0a| `:-  a  b` | `[a b]` | cell |\0a| `%-  f  x` | `(f x)` | call gate |\0a| `` ^-  t  v `` | `` `t`v `` | cast |\0a| `%+  f  a  b` | `(f a b)` | 2-arg call |")
              outputs=~  exec-count=~
          ==
          [3 %code '(add 1 2)' ~ ~]
          [4 %code '%-  add  [1 2]' ~ ~]
          [5 %code (crip "`@p`255") ~ ~]
          [6 %code '^-  @p  255' ~ ~]
          :*  id=7  type=%markdown
              source=(crip "## Building a Gate\0a\0a`|=  sample=type  body` -- the sample declares the input name and type; the body is the return expression.")
              outputs=~  exec-count=~
          ==
          [8 %code (crip "=/  double  |=(a=@ud (mul a 2))\0a(double 5)") ~ ~]
          [9 %code (crip "=/  bigger  |=([a=@ud b=@ud] ?:((gth a b) a b))\0a(bigger 7 3)") ~ ~]
          :*  id=10  type=%markdown
              source=(crip "## Type Fences\0a\0a`^-  type  expr` asserts the return type. This is checked at compile time -- a mismatch is a build error, not a runtime crash.")
              outputs=~  exec-count=~
          ==
          [11 %code (crip "=/  greet\0a  |=  a=@ud\0a  ^-  @t\0a  ?:  (gth a 1)  'yes'  'no'\0a(greet 5)") ~ ~]
          :*  id=12  type=%markdown
              source=(crip "## Recursion with `|-`\0a\0a`|-` (barhep) creates an anonymous recursive gate. Call it again with `$`.")
              outputs=~  exec-count=~
          ==
          [13 %code (crip ":: Triangular number: 1+2+...+n\0a=/  tri\0a  |=  n=@ud\0a  ^-  @ud\0a  =/  i  1\0a  =/  acc  0\0a  |-\0a  ?:  (gth i n)  acc\0a  $(i (add i 1), acc (add acc i))\0a(tri 10)") ~ ~]
        ==
      %hoon
    'Hoon School: 3. Gates'
    :-  'hs-types'
    ^-  notebook
    :+  ^-  (list cell)
        :~
          :*  id=1  type=%markdown
              source=(crip "# 4. Molds (Types)\0a\0aHoon is statically typed with inference. A **mold** is both a type and a normalizing gate. `^-` asserts a type; a mismatch produces a `nest-fail`.")
              outputs=~  exec-count=~
          ==
          :*  id=2  type=%markdown
              source=(crip "## Atoms and Auras\0a\0aAll atoms are unsigned integers. Auras annotate them for display but don't create separate runtime types. Arithmetic strips auras, producing plain `@`.")
              outputs=~  exec-count=~
          ==
          [3 %code '^-  @ud  15' ~ ~]
          [4 %code '^-  *  [13 14]' ~ ~]
          [5 %code (crip "(add 0x15 15)     :: hex + decimal: auras erased, result is @") ~ ~]
          [6 %code (crip "(add 100 0b101)   :: decimal + binary = 105") ~ ~]
          :*  id=7  type=%markdown
              source=(crip "## Cell Types\0a\0a`^` is any cell. `[@ @]` requires a pair of atoms. `[@ud @ux]` specifies the aura of each slot.")
              outputs=~  exec-count=~
          ==
          [8 %code '^-  ^  [12 13]' ~ ~]
          [9 %code '^-  [@ @]  [12 13]' ~ ~]
          [10 %code '^-  [@ud @ux]  [12 0x10]' ~ ~]
          :*  id=11  type=%markdown
              source=(crip "## Bunts\0a\0a`^*  type` (or `*type`) gives the **bunt** -- the default value of a mold. Used when you need a placeholder of the right shape.")
              outputs=~  exec-count=~
          ==
          [12 %code '^*  @ud' ~ ~]
          [13 %code '^*  @da' ~ ~]
          [14 %code '*[@ud @ux @ub]' ~ ~]
          :*  id=15  type=%markdown
              source=(crip "## Vases\0a\0a`!>  expr` (zapgar) wraps a value in a **vase** `[type value]`. Use `-:!>(x)` to extract just the type label.")
              outputs=~  exec-count=~
          ==
          [16 %code '!>(0xace2.bead)' ~ ~]
          [17 %code '-:!>(0xace2.bead)' ~ ~]
          [18 %code (crip "-:!>('hello')") ~ ~]
          :*  id=19  type=%markdown
              source=(crip "## Type Unions\0a\0a`$?` (bucwut) builds a union mold. Use `?-` (wuthep) to switch on a union value -- it must be exhaustive.")
              outputs=~  exec-count=~
          ==
          [20 %code (crip "=/  color  `?(%red %green %blue)`%red\0a?-  color\0a  %red    'is red'\0a  %green  'is green'\0a  %blue   'is blue'\0a==") ~ ~]
        ==
      %hoon
    'Hoon School: 4. Molds'
  ==

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
  ==

++  broadcast
  |=  upd=update
  ^-  card
  [%give %fact [[%notebook ~] ~] %json !>((update-to-json upd))]

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

=|  state-4
=*  state  -
^-  agent:gall
%-  agent:dbug
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)

++  on-init
  ^-  (quip card _this)
  `this(nbs hoon-school-nbs, active 'hs-syntax', ksession ~, counter 100, hoon-subject fresh-subject)

++  on-save  !>(`versioned-state`[%4 nbs active ksession counter hoon-subject])

++  on-load
  |=  old=vase
  ^-  (quip card _this)
  ::  Always reset hoon-subject: stored vases are stale after kernel upgrades.
  =/  try  (mule |.(!<(versioned-state old)))
  ?.  ?=(%& -.try)
    `this(nbs (~(put by *(map @t notebook)) 'main' [~ %hoon 'untitled']), active 'main', ksession ~, counter 0, hoon-subject fresh-subject)
  =/  s  +.p.try
  =/  cleanup=(list card)
    ?~  ksession.s  ~
    ~[[%pass /caderno/session %agent [our.bowl agent.u.ksession.s] %leave ~]]
  :-  cleanup
  this(nbs nbs.s, active active.s, ksession ~, counter counter.s, hoon-subject fresh-subject)

++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %cnb-action
    =/  act  !<(action vase)
    =/  nb  (need (~(get by nbs) active))
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
      ::  shoe kernel: delegate to session via %eval-command
      =/  src  source.u.c
      =/  ses  `@ta`%caderno
      ?~  ksession
        ::  first run: subscribe and queue the command; %eval-command is sent
        ::  reactively when shoe's initial %pro confirms the session is ready
        =/  new-ks  ^-  kernel-session
          :*  agent=kernel.nb
              ses=ses
              pending=`[id src]
              accum=~
              ready=%.n
          ==
        ::  leave then watch: handles stale wire left over from prior on-load
        =/  leave=card
          [%pass /caderno/session %agent [our.bowl kernel.nb] %leave ~]
        =/  watch=card
          :*  %pass  /caderno/session  %agent
              [our.bowl kernel.nb]
              %watch  /sole/(scot %p our.bowl)/caderno
          ==
        :_  this(nbs (~(put by nbs) active nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb))), ksession `new-ks, counter new-count)
        :~  (broadcast [%cell-status id %running])
            leave
            watch
        ==
      ::  session exists; update the queued command
      =/  ks  u.ksession
      =/  new-ks=kernel-session  ks(pending `[id src], accum ~)
      ::  not yet ready: just queue; %eval-command will fire when %pro arrives
      ?:  =(%.n ready.ks)
        :_  this(nbs (~(put by nbs) active nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb))), ksession `new-ks, counter new-count)
        ~[(broadcast [%cell-status id %running])]
      ::  ready: poke North with %eval-command immediately
      =/  eval=card
        :*  %pass  /caderno/eval  %agent
            [our.bowl kernel.nb]
            %poke  %eval-command
            !>([ses (trip src)])
        ==
      :_  this(nbs (~(put by nbs) active nb(cells (replace-cell id u.c(exec-count `new-count) cells.nb))), ksession `new-ks, counter new-count)
      :~  (broadcast [%cell-status id %running])
          eval
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
      =/  subj             fresh-subject
      |-
      ?~  code-cells
        :_  this(nbs (~(put by nbs) active nb(cells cs)), counter ct, hoon-subject subj)
        cd
      =/  c   i.code-cells
      =/  new-ct  +(ct)
      =/  res
        ?:  =(%hoon kernel.nb)
          (eval-hoon source.c subj)
        ::  non-hoon kernel: run-all not supported; emit a placeholder error
        [[%error 'KernelError' 'run-all unsupported for shoe kernels'] subj]
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
      `this(nbs (~(put by nbs) active nb(kernel kernel.act)))
    ::
        %reset-subject
      =/  cleanup=(list card)
        ?~  ksession  ~
        ~[[%pass /caderno/session %agent [our.bowl agent.u.ksession] %leave ~]]
      :-  cleanup
      this(hoon-subject fresh-subject, ksession ~)
        %set-cell-type
      =/  c  (find-cell id.act cells.nb)
      ?~  c  `this
      =/  new-cell  u.c(type type.act, outputs ~, exec-count ~)
      `this(nbs (~(put by nbs) active nb(cells (replace-cell id.act new-cell cells.nb))))
        %set-title
      =/  new-nb  nb(title title.act)
      :_  this(nbs (~(put by nbs) active new-nb))
      ~[(broadcast [%nb-list (nb-list-items (~(put by nbs) active new-nb))])]
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
      :_  this(nbs new-nbs, active new-active)
      :~  (broadcast [%nb-list (nb-list-items new-nbs)])
          (broadcast [%state new-active new-active-nb])
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
      ::  write all notebooks as JSON text to %caderno-log and commit
      =/  soba  (nbs-to-soba nbs)
      :_  this
      :~  [%pass /caderno/clay %arvo %c [%info %caderno-log [%& soba]]]
          [%pass /caderno/hood/commit %agent [our.bowl %hood] %poke %kiln-commit !>([%caderno-log %.n])]
          (broadcast [%log-committed ~])
      ==
    ==
  ==

++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  (on-watch:def path)
      [%notebook ~]
    =/  nb  (need (~(get by nbs) active))
    :_  this
    :~  [%give %fact ~ %json !>((update-to-json [%nb-list (nb-list-items nbs)]))]
        [%give %fact ~ %json !>((update-to-json [%state active nb]))]
    ==
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
    =/  kels=json
      :-  %o
      %-  ~(gas by *(map @t json))
      :~  ['hoon' [%n (scot %ud hoon-kel)]]
          ['arvo' [%n (scot %ud arvo-kel)]]
          ['zuse' [%n (scot %ud zuse-kel)]]
          ['nock' [%n '4']]
          ['port' (numb:enjs:format port)]
      ==
    ``[%json !>(kels)]
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
      =/  new-nb=notebook  (need (~(get by nbs) active))
      |-
      ?~  effects
        :_  this(ksession `new-ks, nbs (~(put by nbs) active new-nb))
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
            :*  %pass  /caderno/eval  %agent
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
        =/  joined  (crip (zing (turn accum.new-ks trip)))
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
        =/  new-cd
          :~  (broadcast [%cell-output cid out exec-ct])
              (broadcast [%cell-status cid %done])
          ==
        %=  $
          effects  t.effects
          new-ks   new-ks(pending ~, accum ~)
          new-nb   upd-nb
          cd       (weld cd new-cd)
        ==
      ==
    ==
      [%caderno %eval ~]
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
