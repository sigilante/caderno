::  /mar/cnb-action.hoon
::  Caderno NoteBook action mark — parses JSON pokes into +$action
::
/-  *caderno
|_  act=action
++  grow
  |%
  ++  noun  act
  --
++  grab
  |%
  ++  noun  action
  ++  json
    |=  j=^json
    ?>  ?=([%o *] j)
    =/  obj  p.j
    ?:  (~(has by obj) 'run-cell')
      =/  inner  (~(got by obj) 'run-cell')
      ?>  ?=([%o *] inner)
      [%run-cell id=(ni:dejs:format (~(got by p.inner) 'id'))]
    ?:  (~(has by obj) 'run-all')
      [%run-all ~]
    ?:  (~(has by obj) 'insert-cell')
      =/  inner  (~(got by obj) 'insert-cell')
      ?>  ?=([%o *] inner)
      =/  im   p.inner
      =/  af   (~(get by im) 'after')
      =/  tp   (so:dejs:format (~(got by im) 'type'))
      =/  ty=cell-type  ?:(=(tp 'code') %code %markdown)
      =/  after=(unit cell-id)
        ?~  af  ~
        ?:  ?=([~ %n *] af)
          `(ni:dejs:format u.af)
        ~
      [%insert-cell after=after type=ty]
    ?:  (~(has by obj) 'delete-cell')
      =/  inner  (~(got by obj) 'delete-cell')
      ?>  ?=([%o *] inner)
      [%delete-cell id=(ni:dejs:format (~(got by p.inner) 'id'))]
    ?:  (~(has by obj) 'update-source')
      =/  inner  (~(got by obj) 'update-source')
      ?>  ?=([%o *] inner)
      =/  im  p.inner
      [%update-source id=(ni:dejs:format (~(got by im) 'id')) src=(so:dejs:format (~(got by im) 'src'))]
    ?:  (~(has by obj) 'set-kernel')
      =/  inner  (~(got by obj) 'set-kernel')
      ?>  ?=([%o *] inner)
      [%set-kernel kernel=(so:dejs:format (~(got by p.inner) 'kernel'))]
    ?:  (~(has by obj) 'reset-subject')
      [%reset-subject ~]
    ?:  (~(has by obj) 'set-cell-type')
      =/  inner  (~(got by obj) 'set-cell-type')
      ?>  ?=([%o *] inner)
      =/  im   p.inner
      =/  tp   (so:dejs:format (~(got by im) 'type'))
      =/  ty=cell-type  ?:(=(tp 'code') %code %markdown)
      [%set-cell-type id=(ni:dejs:format (~(got by im) 'id')) type=ty]
    ?:  (~(has by obj) 'set-title')
      =/  inner  (~(got by obj) 'set-title')
      ?>  ?=([%o *] inner)
      [%set-title title=(so:dejs:format (~(got by p.inner) 'title'))]
    ?:  (~(has by obj) 'new-notebook')
      [%new-notebook ~]
    ?:  (~(has by obj) 'switch-notebook')
      =/  inner  (~(got by obj) 'switch-notebook')
      ?>  ?=([%o *] inner)
      [%switch-notebook id=(so:dejs:format (~(got by p.inner) 'id'))]
    ?:  (~(has by obj) 'delete-notebook')
      =/  inner  (~(got by obj) 'delete-notebook')
      ?>  ?=([%o *] inner)
      [%delete-notebook id=(so:dejs:format (~(got by p.inner) 'id'))]
    !!
  --
++  grad  %noun
--
