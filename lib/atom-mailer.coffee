{CompositeDisposable} = require 'atom'
{$} = require 'atom-space-pen-views'
Imap = require 'imap'
jconv = require 'jconv'
inspect = require('util').inspect
mimelib = require 'mimelib'
inspect = require('util').inspect


createMailerView = (state) ->
  AtomMailerView = require './atom-mailer-view'
  new AtomMailerView(state)

module.exports = AtomMailer =
  atomMailerView: null
  subscriptions: null

  config:
    mailAddress:
      type: "string"
      default: "you@gmail.com"
    mailPassword:
      type: "string"
      default: "password"
    host:
      type: "string"
      default: "imap.gmail.com"
    port:
      type: "integer"
      default: 993
    tlsEnable:
      type: "boolean"
      default: true
    numberOfReceivingMail:
      type: "integer"
      default: 10

  initMailSettings: ->
    @mailAddress = atom.config.get('atom-mailer.mailAddress')
    @mailPassword = atom.config.get('atom-mailer.mailPassword')
    @host = atom.config.get('atom-mailer.host')
    @port = atom.config.get('atom-mailer.port')
    @tlsEnable = atom.config.get('atom-mailer.tlsEnable')

    @imap = new Imap
      user: @mailAddress
      password: @mailPassword
      host: @host
      port: @port
      tls: @tlsEnable

  activate: (state) ->
    atom.workspace.addOpener (uri) =>
      if uri is 'atom-mailer://inbox'
        @atomMailerView = createMailerView(state)

        return @atomMailerView
      else
        return

    @initMailSettings()

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-mailer:open': => @open()

  deactivate: ->
    @subscriptions.dispose()
    #@atomMailerView.destroy()

  getNumberOfReceivingMail: ->
    return '1:' + atom.config.get('atom-mailer.numberOfReceivingMail')

  receiveMail: ->
    @imap.once 'ready', =>
      @openInbox (err, box) =>
        throw err if err
        f = @imap.seq.fetch @getNumberOfReceivingMail(),
          bodies: ['HEADER.FIELDS (FROM TO SUBJECT DATE)','TEXT']
          struct: true

        f.on 'message', (msg, seqno) =>
          msg.on 'body', (stream, info) =>
            buffer = ''
            stream.on 'data', (chunk) =>
              buffer += chunk.toString('utf8')

            stream.on 'end', =>
              if info.which isnt 'TEXT'
                parsedHeader = Imap.parseHeader(buffer)
                @storeMessage seqno, parsedHeader, 'header'
                @atomMailerView.addMessage(parsedHeader, seqno)
              else
                #console.log buffer
                @storeMessage seqno, buffer, 'body'
                @atomMailerView.addBody(buffer, seqno)

          msg.on 'attributes', (attrs) =>
            @storeMessage seqno, attrs, 'attrs'

        f.once 'error', (err) =>
          console.log err

        f.once 'end', =>
          @prepareMessages()
          @eventInit()
          @imap.end()

    @imap.once 'error', (err) =>
      if err.code isnt "ECONNRESET"
        console.log err

    @imap.once 'end', =>
      console.log 'end'

  serialize: ->
    #atomMailerViewState: @atomMailerView.serialize()

  openInbox: (cb) ->
    @imap.openBox('INBOX', true, cb)

  jis2utf: (text)->
    buf = new Buffer(text)
    convertedBuf = jconv.convert buf, 'ISO-2022-JP', 'UTF-8'
    return convertedBuf.toString()

  eventInit: ->
    callback = (event) =>
      #console.log @mailBox[$(this).attr('seqno')].body
      @atomMailerView.openMessage @mailBox[$(event.target).attr('seqno')]

    @atomMailerView.on 'click', 'a', callback

  storeMessage: (seqno, data, type) ->
    @mailBox = {} if !@mailBox?
    if !@mailBox[seqno]?
      @mailBox[seqno] = {}

    @mailBox[seqno][type] = data

  parseAttrs: ( attrs ) ->
    res =
      part: false
      info: {}

    for v in attrs.struct
      if v.type is 'alternative' || v.type is 'mixed'
        res.part = true
        res.boundary = v.params.boundary
      else
        if attrs.struct.length is 1
          res.info[v.partID] =
            type: v.type
            subtype: v.subtype
            encoding: v.encoding
            charset: v.params.charset
        else
          res.info[v[0].partID] =
            type: v[0].type
            subtype: v[0].subtype
            encoding: v[0].encoding
            charset: v[0].params.charset

    return res

  prepareMessages: ->
    Base64 = require('js-base64').Base64
    for key of @mailBox
      attrs = @parseAttrs(@mailBox[key].attrs)
      if attrs.part
        rawBody = @mailBox[key].body.split( '--' + attrs.boundary )
      else
        rawBody = @mailBox[key].body

      @mailBox[key].body = []

      bodyArr = @ignoreContentInfo rawBody
      for attrKey of attrs.info
        bodyData = bodyArr[attrKey - 1]

        switch attrs.info[attrKey].encoding
          when 'base64', 'BASE64'
            bodyData = Base64.decode(bodyData.replace('MIME-Version: 1.0', ''))
            
          when 'quoted-printable', 'QUOTED-PRINTABLE'
            bodyData = mimelib.decodeQuotedPrintable(bodyData)

        switch attrs.info[attrKey].charset
          when 'iso-2022-jp', 'ISO-2022-JP'
            bodyData = @jis2utf(bodyData)

        @mailBox[key].body.push bodyData

  ignoreContentInfo: (data) ->
    if typeof data is 'string'
      return [data]
    newArr = []
    for v in data
      if v isnt "" && v isnt "--"
        if v.indexOf('Content-Type') >= 0
          re = /\n*Content[^\n]*\n*/gm
          newArr.push v.replace(re, '')

    return newArr

  open: ->
    atom.workspace.open('atom-mailer://inbox')
    @initMailSettings()
    @receiveMail()
    @imap.connect()
