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
      [%mount-log ~]
      [%commit-log ~]
      [%import-log ~]
    ::  publishing / following over Gall subscription
      [%publish id=@t]                                  ::  expose a local nb
      [%unpublish id=@t]                                ::  stop exposing it
      [%follow who=@p id=@t]                            ::  subscribe to a remote nb
      [%unfollow who=@p id=@t]                          ::  drop a subscription
      [%fork who=@p id=@t]                              ::  copy a follow into local nbs
      [%lookup who=@p]                                  ::  browse a ship's catalog
      [%unlookup who=@p]                                ::  stop browsing it
    ::  kernel discovery.  Only the UI can tell which agents are shoe agents
    ::  (see /x/kernels in the agent), so it sweeps and reports back here.
      [%set-kernels ids=(list @t)]                      ::  cache a sweep result
      [%rescan-kernels ~]                               ::  drop it, forcing a sweep
  ==

+$  update
  $%  [%state id=@t nb=notebook]
      [%nb-list items=(list [id=@t title=@t])]
      [%cell-output id=cell-id out=output count=@ud]
      [%cell-status id=cell-id status=?(%running %done %error)]
      [%cell-added after=(unit cell-id) c=cell]
      [%cell-deleted id=cell-id]
      [%log-mounted ~]
      [%log-committed ~]
    ::  which local nbs are public, and the remote nbs we follow
      [%published ids=(set @t)]
      [%follows items=(list [who=@p id=@t title=@t])]
    ::  published-list: a ship's catalog served on /published-list.
    ::  lookup: that catalog relayed to our own UI, tagged with the ship.
      [%published-list items=(list [id=@t title=@t])]
      [%lookup who=@p items=(list [id=@t title=@t])]
    ::  discovered shoe kernels still running, %hoon not included
      [%kernels items=(list @t)]
  ==

::  sole session state for shoe kernel delegation
+$  kernel-session
  $:  agent=@tas
      ses=@ta
    ::  pending: the cell currently dispatched, awaiting its %pro
    ::  queue:   cells still to run, dispatched one per %pro (see %run-all)
      pending=(unit [id=cell-id src=@t])
      queue=(list [id=cell-id src=@t])
      accum=(list @t)
      ready=?
  ==
--
