{$, $$, ScrollView} = require 'atom-space-pen-views'

module.exports =
class AtomMailerView extends ScrollView
  @mailBox

  @content: ->
    @div class: 'atom-mailer', tabindex: -1, =>
      @div class: 'message-list', =>
        @ul outlet: 'messageList'
      @div class: 'mail-content panels', =>
        @div outlet: 'mailDefatilTitle', class: 'mail-detail-title'
        @div outlet: 'mailDefatilFrom', class: 'mail-detail-from'
        @div click: 'OpenMessageEvent', outlet: 'mailDetailBody', class: 'mail-body-container', =>
          @iframe outlet: 'mailBody', class: 'mail-body'

  getTitle: ->
    "Mailer"

  getBox: (seqno) ->
    if @mailBox.hasOwnProperty(seqno)
      return @mailBox[seqno]
    else
      return null

  addBody: (body, seqno ) ->
    @mailBox[seqno] = { body: body }

  addMessage: (header, seqno ) ->
    @mailBox[seqno] = { header: header }

    @messageList.append $$ ->
      @li =>
        @a seqno: seqno, "#{header.subject[0]}"

  openMessage: (message) ->
    body = message.body[0].replace(/$/gm, "<br/>")
    if message.body.length > 1
      body = message.body[1]
    @mailBody[0].contentDocument.body.innerHTML = body
    #@mailDetailBody.html(body)

  getIconName: ->
    "mail"

  initialize: (serializeState) ->
    super
    @mailBox = []

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
