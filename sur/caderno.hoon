::  /sur/caderno.hoon
::  shared types for %caderno notebook
::
|%
+$  cell-id    @ud
+$  cell-type  ?(%code %markdown)

::  output datum from a single cell execution
+$  output
  $%  [%text data=@t]
      [%error ename=@t evalue=@t]
  ==

::  a single notebook cell
+$  cell
  $:  id=cell-id
      type=cell-type
      source=@t
      outputs=(list output)
      exec-count=(unit @ud)
  ==

::  the notebook document
+$  notebook
  $:  cells=(list cell)
      kernel=@tas
      title=@t
  ==

::  poke actions (client → app)
+$  action
  $%  [%run-cell id=cell-id]
      [%run-all ~]
      [%insert-cell after=(unit cell-id) type=cell-type]
      [%delete-cell id=cell-id]
      [%update-source id=cell-id src=@t]
  ==

::  subscription update facts (app → client)
+$  update
  $%  [%state nb=notebook]
      [%cell-output id=cell-id out=output]
      [%cell-status id=cell-id status=?(%running %done %error)]
      [%cell-added c=cell]
      [%cell-deleted id=cell-id]
  ==
--
