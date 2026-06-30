::  /sur/caderno.hoon
::  shared types for %caderno notebook
::
|%
+$  cell-id    @ud
+$  cell-type  ?(%code %markdown)

+$  output
  $%  [%text data=@t]
      [%error ename=@t evalue=@t]
  ==

+$  cell
  $:  id=cell-id
      type=cell-type
      source=@t
      outputs=(list output)
      exec-count=(unit @ud)
  ==

+$  notebook
  $:  cells=(list cell)
      kernel=@tas
      title=@t
  ==

+$  action
  $%  [%run-cell id=cell-id]
      [%run-all ~]
      [%insert-cell after=(unit cell-id) type=cell-type]
      [%delete-cell id=cell-id]
      [%update-source id=cell-id src=@t]
      [%set-kernel kernel=@tas]
      [%reset-subject ~]
      [%set-cell-type id=cell-id type=cell-type]
      [%set-title title=@t]
      [%new-notebook ~]
      [%switch-notebook id=@t]
      [%delete-notebook id=@t]
  ==

+$  update
  $%  [%state id=@t nb=notebook]
      [%nb-list items=(list [id=@t title=@t])]
      [%cell-output id=cell-id out=output count=@ud]
      [%cell-status id=cell-id status=?(%running %done %error)]
      [%cell-added after=(unit cell-id) c=cell]
      [%cell-deleted id=cell-id]
  ==

::  sole session state for shoe kernel delegation
+$  kernel-session
  $:  agent=@tas
      ses=@ta
      pending=(unit [id=cell-id src=@t])
      accum=(list @t)
      ready=?
  ==
--
