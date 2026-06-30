::  /mar/caderno-action.hoon
/-  *caderno
|_  a=action
++  grab
  |%
  ++  noun  action
  ++  json
    |=  j=^json
    ^-  action
    ?>  ?=([%o *] j)
    =/  obj  p.j
    ?:  (~(has by obj) 'run-cell')
      =/  inner  (~(got by obj) 'run-cell')
      ?>  ?=([%o *] inner)
      [%run-cell (ni:dejs:format (~(got by p.inner) 'id'))]
    ?:  (~(has by obj) 'run-all')
      [%run-all ~]
    ?:  (~(has by obj) 'insert-cell')
      =/  inner  (~(got by obj) 'insert-cell')
      ?>  ?=([%o *] inner)
      =/  im   p.inner
      =/  aj   (~(get by im) 'after')
      =/  after=(unit cell-id)
        ?~  aj  ~
        ?:  =(~ u.aj)  ~
        `(ni:dejs:format u.aj)
      =/  tp   (so:dejs:format (~(got by im) 'type'))
      =/  ty=cell-type  ?:(=(tp 'code') %code %markdown)
      [%insert-cell after=after type=ty]
    ?:  (~(has by obj) 'delete-cell')
      =/  inner  (~(got by obj) 'delete-cell')
      ?>  ?=([%o *] inner)
      [%delete-cell (ni:dejs:format (~(got by p.inner) 'id'))]
    ?:  (~(has by obj) 'update-source')
      =/  inner  (~(got by obj) 'update-source')
      ?>  ?=([%o *] inner)
      =/  im   p.inner
      [%update-source id=(ni:dejs:format (~(got by im) 'id')) src=(so:dejs:format (~(got by im) 'src'))]
    ?:  (~(has by obj) 'set-kernel')
      =/  inner  (~(got by obj) 'set-kernel')
      ?>  ?=([%o *] inner)
      [%set-kernel kernel=`@tas`(so:dejs:format (~(got by p.inner) 'kernel'))]
    !!
  --
++  grow
  |%
  ++  noun  a
  --
++  form  `mark`%caderno-action
--
