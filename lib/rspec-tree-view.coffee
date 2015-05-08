{Disposable, CompositeDisposable} = require 'atom'
{View, $$} = require 'atom-space-pen-views'
{TreeView} = require './tree-view'

PluginState = require './plugin-state'
RSpecTestDetails = require './rspec-test-details'

module.exports =
class RSpecTreeView extends View
  @content: ->
    @div class: 'rspec-tree-runner tool-panel focusable-panel', =>
      @h3 class: 'tree-view-title', ''
      @div class: 'spec-does-not-exist', =>
        @h2 'It seems that this file doesn\'t have spec file'
        @h3 'Press ctrl-alt-q to create a new one'
        @div class: 'file-to-analyze'
      @div class: 'not-ruby-file', =>
        @h2 'It seems that this is not a ruby file'
        @h3 'The file must have the extension .rb'
      @div class: 'tests-summary', =>
        @div class: 'tests-summary-container', =>
          @div class: 'tests-summary-passed', =>
            @div class: 'number', '-'
            @div class: 'text', 'passed'
          @div class: 'tests-summary-failed', =>
            @div class:'number', '-'
            @div class: 'text', 'failed'
          @div class: 'tests-summary-pending', =>
            @div class: 'number', '-'
            @div class: 'text', 'pending'
      @div class: 'rspec-tree-runner-view-container'

  initialize:  ->
    @currentState = new PluginState

    @currentState.onTreeBuilt (result) =>
      @setStdErrorNotification(result)
      @redrawTree(result.asTree, result)

    @currentState.onSpecFileBeingAnalyzed =>
      @treeView.displayLoading('Spec file being analyzed') if @treeView?

    @currentState.onTestsRunning =>
      @treeView.displayLoading('RSpec running tests') if @treeView?

    @setCurrentAndCorrespondingFile(atom.workspace.getActiveTextEditor())

    @treeView = new TreeView

    @treeView.onDblClick ({item}) =>
      if item.exception?
        @rspecTestDetails.setVisible(true)
        @rspecTestDetails.setContent(item.exception)

    this.find('.rspec-tree-runner-view-container').append(@treeView)

    @disposables = new CompositeDisposable

  setStdErrorNotification: (result) ->
    return unless result.stdErrorData?

    return unless result.stdErrorData.length > 0

    dataToDisplay = ""

    if result.stdErrorData.length > 350
      dataToDisplay = result.stdErrorData.substring(0, 350).concat("...")

    if result.summary?
      atom.notifications.addWarning("RSpec is running with warnings", { detail: dataToDisplay });
    else
      atom.notifications.addError("RSpec has failed", { detail: dataToDisplay });

  redrawTree: (asTree, testsResults) ->
    children = asTree || {}

    if @treeView?
      @treeView.setRoot({ label: 'root', children: children })
      @displayFile(true)
      @treeView.hideLoading()

      if testsResults? and testsResults.summary?
        @updateSummary({
          passed: testsResults.summary.example_count - testsResults.summary.failure_count,
          failed: testsResults.summary.failure_count,
          pending: testsResults.summary.pending_count
        })

  setCurrentAndCorrespondingFile: (editor) ->
    @currentState.set(editor)

    if @currentState.currentFilePathExtension != "rb"
      this.find('.not-ruby-file').show()
      this.find('.spec-does-not-exist').hide()
      this.find('.tests-summary').hide()
      this.find('.rspec-tree-runner-view-container').hide()
      this.find('.tree-view-title').hide()
      return
    else
      this.find('.not-ruby-file').hide()
      this.find('.rspec-tree-runner-view-container').show()

    @changeFile(@currentState.currentFileName)

    if @currentState.specFileExists
      this.find('.spec-does-not-exist').hide()
      this.find('.tests-summary').show()
    else
      @redrawTree({})
      this.find('.spec-does-not-exist').show()
      this.find('.tests-summary').hide()
      @treeView.hide if @treeView?

  changeFile: (fileName) ->
    title = this.find('.tree-view-title')
    title.show()
    title.text(fileName)

  displayFile: (display) ->
    title = this.find('.tree-view-title')
    if display then title.show() else title.hide()

  updateSummary: (summary) ->
    this.find('.tests-summary-passed .number').html(summary.passed)
    this.find('.tests-summary-failed .number').html(summary.failed)
    this.find('.tests-summary-pending .number').html(summary.pending)

  handleEditorEvents: (editor) ->
    if editor?
      this.show()
      @setCurrentAndCorrespondingFile(editor)
    else
      this.hide()

  runTests: ->
    return unless @currentState.specFileExists

    @currentState.runTests()

  toggleSpecFile: ->
    atom.workspace.open(@currentState.currentCorrespondingFilePath) if @currentState.currentCorrespondingFilePath?

  toggle: ->
    return unless @panel

    if @panel.isVisible()
      @panel.hide()
    else
      @panel.show()

  attach: ->
    @rspecTestDetails = new RSpecTestDetails

    @panel = atom.workspace.addRightPanel(item: this, visible: false)

    @disposables.add new Disposable =>
      @panel.destroy()
      @panel = null

    @disposables.add new Disposable =>
      @rspecTestDetails.panel.destroy()
      @rspecTestDetails.panel = null


    @disposables.add atom.workspace.onDidChangeActivePaneItem (editor) =>
      @handleEditorEvents(editor)

  detach: ->
    @disposables.dispose()
    @editorHandlers?.dispose()

  destroy: ->
    @detach()