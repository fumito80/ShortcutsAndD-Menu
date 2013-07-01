// Generated by CoffeeScript 1.6.3
(function() {
  var $, BookmarksView, CommandInputView, CommandsView, Config, HeaderView, KeyConfig, KeyConfigSet, KeyConfigSetView, KeyConfigView, PopupBaseView, WebFontConfig, catnames, commandsDisp, endEditing, escape, fk, keyCodes, keys, marginBottom, optionsDisp, resizeTimer, saveData, scHelp, scHelpSect, startEditing, windowOnResize, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  PopupBaseView = Backbone.View.extend({
    events: {
      "submit form": "onSubmitForm",
      "click  .icon-remove": "onClickIconRemove"
    },
    render: function() {},
    onShowPopup: function(name, id) {
      if (name !== this.name) {
        return false;
      }
      this.modelId = id;
      this.render();
      this.el.style.pixelLeft = (window.innerWidth - this.$el.width()) / 2;
      this.el.style.pixelTop = Math.round((window.innerHeight - this.$el.height()) / 2);
      this.$el.show();
      return $(".backscreen").show();
    },
    onClickIconRemove: function() {
      return this.hidePopup();
    },
    hidePopup: function() {
      $(".backscreen").hide();
      return this.$el.hide();
    }
  });

  commandsDisp = {
    closeOtherTabs: ["tab", "Close other tabs"],
    closeTabsLeft: ["tab", "Close tabs to the left"],
    closeTabsRight: ["tab", "Close tabs to the right"],
    moveTabLeft: ["tab", "Move current tab left"],
    moveTabRight: ["tab", "Move current tab right"],
    moveTabFirst: ["tab", "Move current tab to first position"],
    moveTabLast: ["tab", "Move current tab to last position"],
    duplicateTab: ["tab", "Duplicate a current tab"],
    duplicateTabWin: ["tab", "Duplicate a current tab to a new window"],
    pinTab: ["tab", "Pin a current tab"],
    unpinTab: ["tab", "Unpin a current tab"],
    detachTab: ["tab", "Detaches a current tab"],
    switchNextWin: ["win", "Switches to the next window"],
    switchPrevWin: ["win", "Switches to the previous window"],
    pasteText: ["custom", "Paste text"]
  };

  catnames = {
    tab: "Tab commands",
    win: "Window commands",
    custom: "Custom commands"
  };

  CommandInputView = (function(_super) {
    __extends(CommandInputView, _super);

    function CommandInputView() {
      _ref = CommandInputView.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    CommandInputView.prototype.name = "commandInput";

    CommandInputView.prototype.el = ".commandInput";

    CommandInputView.prototype.render = function() {
      this.$(".command").text("Input for " + commandsDisp[this.command.name][1] + ":");
      this.$(".caption").val(this.command.caption);
      return this.$(".content").val(this.command.content);
    };

    CommandInputView.prototype.onShowPopup = function(name, id, options) {
      this.command = options;
      if (!CommandInputView.__super__.onShowPopup.call(this, name, id)) {
        return;
      }
      if (this.command.content) {
        return this.$(".content").focus();
      } else {
        return this.$(".caption").focus();
      }
    };

    CommandInputView.prototype.onSubmitForm = function() {
      this.trigger("setCommand", this.modelId, {
        name: this.command.name,
        category: this.command.category,
        caption: this.$(".caption").val(),
        content: this.$(".content").val()
      });
      this.hidePopup();
      return false;
    };

    return CommandInputView;

  })(PopupBaseView);

  CommandsView = (function(_super) {
    __extends(CommandsView, _super);

    CommandsView.prototype.name = "command";

    CommandsView.prototype.el = ".commands";

    function CommandsView(options) {
      CommandsView.__super__.constructor.call(this, options);
      this.commandInputView = options.commandInputView;
    }

    CommandsView.prototype.render = function() {
      var categories, key, target$;
      target$ = this.$(".commandRadios");
      target$.empty();
      categories = [];
      for (key in commandsDisp) {
        categories.push(commandsDisp[key][0]);
      }
      categories = _.unique(categories);
      categories.forEach(function(cat) {
        return target$.append("<div class=\"cat" + cat + "\"><div class=\"catname\">" + catnames[cat] + "</div>");
      });
      for (key in commandsDisp) {
        target$.find(".cat" + commandsDisp[key][0]).append(this.tmplItem({
          key: key,
          value: commandsDisp[key][1]
        }));
      }
      return this;
    };

    CommandsView.prototype.onShowPopup = function(name, id, options) {
      if (!CommandsView.__super__.onShowPopup.call(this, name, id)) {
        return;
      }
      if (options) {
        return this.$(".radioCommand").val([options.name]);
      }
    };

    CommandsView.prototype.onSubmitForm = function() {
      var category, command;
      if (command = this.$(".radioCommand:checked").val()) {
        if ((category = commandsDisp[command][0]) === "custom") {
          this.trigger("showPopup", "commandInput", this.modelId, {
            name: command,
            category: category
          });
          this.$el.hide();
        } else {
          this.trigger("setCommand", this.modelId, {
            name: command
          });
          this.hidePopup();
        }
      }
      return false;
    };

    CommandsView.prototype.tmplItem = _.template("<div>\n  <label>\n    <input type=\"radio\" name=\"radioCommand\" class=\"radioCommand\" value=\"<%=key%>\">\n    <%=value%>\n  </label>\n</div>");

    return CommandsView;

  })(PopupBaseView);

  BookmarksView = (function(_super) {
    __extends(BookmarksView, _super);

    BookmarksView.prototype.name = "bookmark";

    BookmarksView.prototype.el = ".bookmarks";

    BookmarksView.prototype.events = _.extend({
      "click  a": "onClickBookmark",
      "click  .title": "onClickFolder",
      "click  .expand-icon": "onClickExpandIcon",
      "click  .expand": "onClickExpand"
    }, PopupBaseView.prototype.events);

    function BookmarksView(options) {
      var ctx;
      BookmarksView.__super__.constructor.call(this, options);
      this.elBookmark$ = this.$(".result");
      ctx = document.getCSSCanvasContext('2d', 'triangle', 8, 5.5);
      ctx.fillStyle = '#000000';
      ctx.translate(.5, .5);
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(0, 1);
      ctx.lineTo(3.5, 4.5);
      ctx.lineTo(7, 1);
      ctx.lineTo(7, 0);
      ctx.closePath();
      ctx.fill();
      ctx.stroke();
      this.$(".result_outer").niceScroll({
        cursorwidth: 12,
        cursorborderradius: 6,
        smoothscroll: true,
        cursoropacitymin: .1,
        cursoropacitymax: .6
      });
    }

    BookmarksView.prototype.render = function() {
      var height;
      height = window.innerHeight - 60;
      this.$(".result_outer").height(height - 30);
      this.$el.height(height);
      if (this.$(".result").children().length === 0) {
        this.onSubmitForm();
      }
      return this;
    };

    BookmarksView.prototype.onClickFolder = function(event) {
      var target$, visible;
      visible = (target$ = $(event.currentTarget).parent()).hasClass("opened");
      if (visible) {
        target$.removeClass("opened expanded");
      } else {
        target$.addClass("opened expanded");
      }
      windowOnResize();
      return event.stopPropagation();
    };

    BookmarksView.prototype.onClickExpandIcon = function(event) {
      var expanded, target$;
      expanded = (target$ = $(event.currentTarget).parent()).hasClass("expanded");
      if (expanded) {
        target$.removeClass("expanded");
      } else {
        target$.addClass("expanded");
      }
      windowOnResize();
      return event.stopPropagation();
    };

    BookmarksView.prototype.onClickExpand = function() {
      if (this.$(".expand").is(":checked")) {
        this.$(".folder").addClass("opened expanded");
      } else {
        this.$(".folder").removeClass("opened expanded");
      }
      return windowOnResize();
    };

    BookmarksView.prototype.onShowPopup = function(name, id) {
      var target;
      if (!BookmarksView.__super__.onShowPopup.call(this, name, id)) {
        return;
      }
      if ((target = this.$("input.query")).val()) {
        target.focus();
      }
      return this.$(".result_outer").getNiceScroll().show();
    };

    BookmarksView.prototype.onSubmitForm = function() {
      var query, state,
        _this = this;
      this.$(".result").empty();
      query = this.$("input.query").focus().val();
      if (query) {
        this.$(".expand")[0].checked = true;
      }
      state = this.$(".expand").is(":checked") ? "opened expanded" : "";
      chrome.bookmarks.getTree(function(treeNode) {
        var recent;
        treeNode.forEach(function(node) {
          return _this.digBookmarks(node, _this.elBookmark$, query, 0, state);
        });
        _this.elBookmark$.append(recent = $(_this.tmplFolder({
          "title": "Recent",
          "state": state,
          "indent": 0
        })));
        recent.find(".title").prepend("<img src=\"images/star.png\">");
        return chrome.bookmarks.getRecent(50, function(treeNode) {
          return treeNode.forEach(function(node) {
            return _this.digBookmarks(node, recent, query, 1, state);
          });
        });
      });
      return false;
    };

    BookmarksView.prototype.digBookmarks = function(node, parent, query, indent, state) {
      var newParent,
        _this = this;
      if (node.title) {
        node.state = state;
        if (node.children) {
          node.indent = indent;
          parent.append(newParent = $(this.tmplFolder(node)));
          parent = newParent;
        } else {
          if (!query || (node.title + " " + node.url).toUpperCase().indexOf(query.toUpperCase()) > -1) {
            node.indent = indent + 1;
            parent.append($(this.tmplLink(node)));
          }
        }
      } else {
        indent--;
      }
      if (node.children) {
        parent.parent().addClass("hasFolder");
        return node.children.forEach(function(child) {
          return _this.digBookmarks(child, parent, query, indent + 1, state);
        });
      }
    };

    BookmarksView.prototype.hidePopup = function() {
      this.$(".result_outer").getNiceScroll().hide();
      return BookmarksView.__super__.hidePopup.call(this);
    };

    BookmarksView.prototype.onClickBookmark = function(event) {
      var target;
      target = $(event.currentTarget);
      this.trigger("setBookmark", this.modelId, {
        title: target.text(),
        url: target.attr("title"),
        bmId: target.attr("data-id")
      });
      return this.hidePopup();
    };

    BookmarksView.prototype.tmplFolder = _.template("<div class=\"folder <%=state%>\" style=\"text-indent:<%=indent%>em\">\n  <span class=\"expand-icon\"></span><span class=\"title\"><%=title%></span>\n</div>");

    BookmarksView.prototype.tmplLink = _.template("<div class=\"link\" style=\"text-indent:<%=indent%>em;\">\n  <a href=\"#\" title=\"<%=url%>\" data-id=\"<%=id%>\" style=\"background-image:-webkit-image-set(url('chrome://favicon/size/16@1x/<%=url%>') 1x);\"><%=title%></a>\n</div>");

    return BookmarksView;

  })(PopupBaseView);

  keyCodes = {};

  keys = null;

  WebFontConfig = {
    google: {
      families: ['Noto+Sans::latin']
    }
  };

  optionsDisp = {
    assignOrg: "None",
    command: "Command",
    bookmark: "Bookmark",
    simEvent: "Simurate key event",
    disabled: "Disabled",
    through: "Through"
  };

  escape = function(html) {
    var entity;
    entity = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;"
    };
    return html.replace(/[&<>]/g, function(match) {
      return entity[match];
    });
  };

  HeaderView = Backbone.View.extend({
    scHelpUrl: "https://support.google.com/chrome/answer/157179?hl=",
    el: "div.header",
    events: {
      "click button.addKeyConfig": "onClickAddKeyConfig",
      "change select.kbdtype": "onChangeSelKbd"
    },
    initialize: function(options) {
      var kbdtype, selectKbd$,
        _this = this;
      keys = keyCodes[kbdtype = this.model.get("kbdtype")].keys;
      selectKbd$ = this.$("select.kbdtype");
      $.each(keyCodes, function(key, item) {
        return selectKbd$.append("<option value=\"" + key + "\">" + item.name + "</option>");
      });
      selectKbd$.val(kbdtype);
      return this.setScHelp(kbdtype);
    },
    onClickAddKeyConfig: function(event) {
      return this.trigger("clickAddKeyConfig", event);
    },
    onChangeSelKbd: function(event) {
      this.trigger("changeSelKbd", event);
      return this.setScHelp(this.$("select.kbdtype").val());
    },
    setScHelp: function(kbdtype) {
      if (kbdtype === "JP") {
        return this.$(".scHelp").text("ショートカットキー一覧").attr("href", this.scHelpUrl + "ja");
      } else {
        return this.$(".scHelp").text("Keyboard shortcuts").attr("href", this.scHelpUrl + "en");
      }
    }
  });

  Config = Backbone.Model.extend({});

  KeyConfig = Backbone.Model.extend({
    idAttribute: "proxy",
    defaults: {
      mode: "assignOrg"
    }
  });

  KeyConfigSet = Backbone.Collection.extend({
    model: KeyConfig
  });

  KeyConfigView = Backbone.View.extend({
    kbdtype: null,
    optionKeys: [],
    events: {
      "click .origin,.proxy": "onClickInput",
      "click div.mode": "onClickMode",
      "click i.memo": "onClickEditMemoIcon",
      "click i.custom": "onClickEditCustomIcon",
      "click .selectMode div": "onChangeMode",
      "click i.icon-remove": "onClickRemove",
      "click input.memo": "onClickInputMemo",
      "submit .memo": "onSubmitMemo",
      "blur  .selectMode": "onBlurSelectMode",
      "blur  input.memo": "onBlurInputMemo"
    },
    initialize: function(options) {
      this.optionKeys = _.keys(optionsDisp);
      this.model.on({
        "change:bookmark": this.onChangeBookmark,
        "change:command": this.onChangeCommand,
        "setFocus": this.onClickInput,
        "remove": this.onRemove
      }, this);
      return this.model.collection.on({
        "kbdEvent": this.onKbdEvent,
        "changeKbd": this.onChangeKbd,
        "updateOrder": this.onUpdateOrder
      }, this);
    },
    render: function(kbdtype) {
      var mode;
      this.setElement(this.template({
        options: optionsDisp
      }));
      mode = this.model.get("mode");
      this.setKbdValue(this.$(".proxy"), this.model.id);
      this.setKbdValue(this.$(".origin"), this.model.get("origin"));
      this.kbdtype = kbdtype;
      this.onChangeMode(null, mode);
      return this;
    },
    onChangeBookmark: function() {
      return this.onChangeMode(null, "bookmark");
    },
    onChangeCommand: function() {
      return this.onChangeMode(null, "command");
    },
    onRemove: function() {
      this.model.off(null, null, this);
      this.off(null, null, null);
      return this.remove();
    },
    onKbdEvent: function(value) {
      var container, input$;
      input$ = this.$("div:focus");
      if (input$.length > 0) {
        if (input$.hasClass("proxy")) {
          if (this.model.id !== value && this.model.collection.findWhere({
            proxy: value
          })) {
            this.trigger("decodeKbdEvent", value, container = {});
            $("#tiptip_content").text("\"" + container.result + "\" is already exists.");
            input$.tipTip();
            return;
          }
        } else {
          if (~~value.substring(2) > 0x200) {
            return;
          }
        }
        this.setKbdValue(input$, value);
        this.model.set(input$[0].className.match(/(proxy|origin)/)[0], value);
        this.setDesc();
        return this.trigger("resizeInput");
      }
    },
    onChangeKbd: function(kbdtype) {
      this.kbdtype = kbdtype;
      this.setKbdValue(this.$(".proxy"), this.model.id);
      this.setKbdValue(this.$(".origin"), this.model.get("origin"));
      return this.setDesc();
    },
    onUpdateOrder: function() {
      return this.model.set("ordernum", this.$el.parent().children().index(this.$el));
    },
    onClickEditCustomIcon: function() {
      return this.trigger("showPopup", "commandInput", this.model.id, this.model.get("command"));
    },
    onClickInputMemo: function() {
      return event.stopPropagation();
    },
    onClickEditMemoIcon: function() {
      var editing, input$, memo;
      (memo = this.$("div.memo")).toggle();
      editing = (input$ = this.$("form.memo").toggle().find("input.memo")).is(":visible");
      if (editing) {
        input$.focus().val(memo.text());
      } else {
        this.onSubmitMemo();
      }
      return event.stopPropagation();
    },
    onSubmitMemo: function() {
      this.$("form.memo").hide();
      this.model.set({
        "memo": this.$("div.memo").show().html(escape(this.$("input.memo").val())).text()
      });
      return false;
    },
    onClickMode: function() {
      if (this.$(".selectMode").toggle().is(":visible")) {
        this.$(".selectMode").focus();
        this.$(".mode").addClass("selecting");
      } else {
        this.$(".mode").removeClass("selecting");
      }
      return event.stopPropagation();
    },
    onChangeMode: function(event, mode) {
      if (event) {
        this.$(".mode").removeClass("selecting");
        mode = event.currentTarget.className;
        this.$(".selectMode").hide();
        if (mode === "bookmark" || mode === "command") {
          this.trigger("showPopup", mode, this.model.id, this.model.get(mode));
          return;
        }
      }
      this.model.set("mode", mode);
      this.$(".mode").removeClass(this.optionKeys.join(" ")).addClass(mode);
      this.setDispMode(mode);
      this.setDesc();
      return this.trigger("resizeInput");
    },
    onBlurSelectMode: function() {
      this.$(".selectMode").hide();
      return this.$(".mode").removeClass("selecting");
    },
    onClickInput: function(event, selector) {
      if (event) {
        $(event.currentTarget).focus();
      } else if (selector) {
        this.$(selector).focus();
      } else {
        this.$(".origin").focus();
      }
      return event != null ? event.stopPropagation() : void 0;
    },
    onBlurInputMemo: function() {
      return this.onSubmitMemo();
    },
    onClickRemove: function() {
      return this.trigger("removeConfig", this.model);
    },
    setDispMode: function(mode) {
      this.$("div.mode").addClass(mode).find("span").text(optionsDisp[mode]);
      this.$(".proxy,.origin,.icon-arrow-right").removeClass(this.optionKeys.join(" ")).addClass(mode);
      if (mode === "assignOrg") {
        this.$(".origin").attr("tabIndex", "0");
        this.$("td:first").removeAttr("colspan");
        return this.$("td:eq(1),td:eq(2)").show();
      } else {
        this.$(".origin").removeAttr("tabIndex");
        this.$("td:first").attr("colspan", "3");
        return this.$("td:eq(1),td:eq(2)").hide();
      }
    },
    setKbdValue: function(input$, value) {
      var container;
      this.trigger("decodeKbdEvent", value, container = {});
      if (container.result) {
        return input$.html(_.map(container.result.split(" + "), function(s) {
          return "<span>" + s + "</span>";
        }).join("+"));
      }
    },
    setDesc: function() {
      var command, commandDisp, content, content3row, desc, help, i, key, keycombo, lang, lines, mode, tdDesc, test, url, _i, _j, _ref1, _ref2;
      (tdDesc = this.$(".desc")).empty();
      switch (mode = this.model.get("mode")) {
        case "bookmark":
          url = this.model.get("bookmark").url;
          tdDesc.append("<div class=\"bookmark\" title=\"" + url + "\" style=\"background-image:-webkit-image-set(url(chrome://favicon/size/16@1x/" + url + ") 1x);\">" + (this.model.get("bookmark").title) + "</div>");
          break;
        case "command":
          desc = (commandDisp = commandsDisp[this.model.get("command").name])[1];
          if (commandDisp[0] === "custom") {
            command = this.model.get("command");
            content3row = [];
            lines = command.content.split("\n");
            for (i = _i = 0, _ref1 = lines.length; 0 <= _ref1 ? _i < _ref1 : _i > _ref1; i = 0 <= _ref1 ? ++_i : --_i) {
              if (i > 2) {
                content3row[i - 1] += " ...";
                break;
              } else {
                content3row.push(lines[i]);
              }
            }
            tdDesc.append(this.tmplCommandCustom({
              desc: desc,
              content3row: content3row.join("<br>"),
              caption: command.caption
            }));
          } else {
            tdDesc.append("<div class=\"commandIcon\">Cmd</div><div class=\"command\">" + desc + "</div>");
          }
          break;
        case "assignOrg":
        case "through":
        case "disabled":
          lang = this.kbdtype === "JP" ? "ja" : "en";
          if (mode === "assignOrg") {
            keycombo = this.$(".origin").text();
          } else {
            keycombo = this.$(".proxy").text();
          }
          keycombo = (keycombo.replace(/\s/g, "")).toUpperCase();
          if (!(help = scHelp[keycombo])) {
            if (/^CTRL\+[2-7]$/.test(keycombo)) {
              help = scHelp["CTRL+1"];
            }
          }
          if (help) {
            for (i = _j = 0, _ref2 = help[lang].length; 0 <= _ref2 ? _j < _ref2 : _j > _ref2; i = 0 <= _ref2 ? ++_j : --_j) {
              test = help[lang][i].match(/(^\w+)\^(.+)/);
              key = RegExp.$1;
              content = RegExp.$2;
              tdDesc.append(this.tmplHelp({
                sectDesc: scHelpSect[key],
                sectKey: key,
                scHelp: content
              })).find(".sectInit").tooltip({
                position: {
                  my: "left+10 top-60"
                }
              });
            }
          }
      }
      if (tdDesc.html() === "") {
        return tdDesc.append(this.tmplMemo({
          memo: this.model.get("memo")
        }));
      }
    },
    tmplMemo: _.template("<div>\n  <i class=\"memo icon-pencil\" title=\"Edit description\"></i>\n</div>\n<form class=\"memo\">\n  <input type=\"text\" class=\"memo\">\n</form>\n<div class=\"memo\"><%=memo%></div>"),
    tmplCommandCustom: _.template("<div class=\"commandIcon\">Cmd</div>\n<div class=\"command\"><%=desc%>: <span class=\"caption\"><%=caption%></span></div>\n<i class=\"custom icon-pencil\"></i><div class=\"content3row\"><%=content3row%></div>"),
    tmplHelp: _.template("<div class=\"sectInit\" title=\"<%=sectDesc%>\"><%=sectKey%></div><div class=\"content\"><%=scHelp%></div>"),
    template: _.template("<tr class=\"data\">\n  <td>\n    <div class=\"proxy\" tabIndex=\"0\"></div>\n  </td>\n  <td>\n    <i class=\"icon-arrow-right\"></i>\n  </td>\n  <td class=\"tdOrigin\">\n    <div class=\"origin\" tabIndex=\"0\"></div>\n  </td>\n  <td class=\"options\">\n    <div class=\"mode\"><span></span><i class=\"icon-caret-down\"></i></div>\n    <div class=\"selectMode\" tabIndex=\"0\">\n      <% _.each(options, function(name, key) { %>\n      <div class=\"<%=key%>\"><%=name%></div>\n      <% }); %>\n    </div>\n  <td class=\"desc\"></td>\n  <td class=\"remove\">\n    <i class=\"icon-remove\" title=\"Delete\"></i>\n  </td>\n  <td class=\"blank\">&nbsp;</td>\n</tr>")
  });

  KeyConfigSetView = Backbone.View.extend({
    placeholder: "Enter new shortcut key",
    el: "table.keyConfigSetView",
    events: {
      "blur div.addnew": "onBlurAddnew",
      "click": "onClickBlank"
    },
    initialize: function(options) {
      this.collection.comparator = function(model) {
        return model.get("ordernum");
      };
      return this.collection.on({
        add: this.onAddRender,
        kbdEvent: this.onKbdEvent
      }, this);
    },
    render: function(keyConfigSet) {
      var _this = this;
      this.$el.append(this.template());
      this.collection.set(keyConfigSet);
      this.$("tbody").sortable({
        delay: 300,
        scroll: true,
        cursor: "move",
        update: function() {
          return _this.onUpdateSort();
        },
        start: function() {
          return _this.onStartSort();
        },
        stop: function() {
          return _this.onStopSort();
        }
      });
      $(".fixed-table-container-inner").niceScroll({
        cursorwidth: 12,
        cursorborderradius: 2,
        smoothscroll: true,
        cursoropacitymin: .3,
        cursoropacitymax: .7,
        zindex: 999998
      });
      this.niceScroll = $(".fixed-table-container-inner").getNiceScroll();
      return this;
    },
    onAddRender: function(model) {
      var keyConfigView, newChild;
      keyConfigView = new KeyConfigView({
        model: model
      });
      keyConfigView.on("decodeKbdEvent", this.onChildDecodeKbdEvent, this);
      keyConfigView.on("removeConfig", this.onChildRemoveConfig, this);
      keyConfigView.on("resizeInput", this.onChildResizeInput, this);
      keyConfigView.on("showPopup", this.onShowPopup, this);
      return this.$("tbody").append(newChild = keyConfigView.render(this.model.get("kbdtype")).$el).append(this.tmplBorder);
    },
    onKbdEvent: function(value) {
      var model, newitem, originValue, target;
      if (this.$(".addnew").length === 0) {
        if ((target = this.$(".proxy:focus,.origin:focus")).length === 0) {
          if (model = this.collection.get(value)) {
            model.trigger("setFocus", null, ".proxy");
            return;
          } else {
            if (!this.onClickAddKeyConfig()) {
              return;
            }
          }
        } else {
          return;
        }
      }
      if (this.collection.findWhere({
        proxy: value
      })) {
        $("#tiptip_content").text("\"" + (this.decodeKbdEvent(value)) + "\" is already exists.");
        this.$("div.addnew").tipTip();
        return;
      }
      this.$("div.addnew").blur();
      if (~~value.substring(2) > 0x200) {
        originValue = "0130";
      } else {
        originValue = value;
      }
      this.collection.add(newitem = new KeyConfig({
        proxy: value,
        origin: originValue
      }));
      this.$("tbody").sortable("enable").sortable("refresh");
      windowOnResize();
      this.onChildResizeInput();
      return newitem.trigger("setFocus");
    },
    onChildDecodeKbdEvent: function(value, container) {
      return container.result = this.decodeKbdEvent(value);
    },
    onChildRemoveConfig: function(model) {
      this.collection.remove(model);
      this.onStopSort();
      windowOnResize();
      return this.onChildResizeInput();
    },
    onChildResizeInput: function() {
      var _this = this;
      this.$(".th_inner").css("left", 0);
      return setTimeout((function() {
        return _this.$(".th_inner").css("left", "");
      }), 0);
    },
    onShowPopup: function(name, modelId, options) {
      return this.trigger("showPopup", name, modelId, options);
    },
    onSetBookmark: function(modelId, options) {
      return this.collection.get(modelId).set({
        "bookmark": options
      }, {
        silent: true
      }).trigger("change:bookmark");
    },
    onSetCommand: function(modelId, options) {
      return this.collection.get(modelId).set({
        "command": options
      }, {
        silent: true
      }).trigger("change:command");
    },
    onClickAddKeyConfig: function(event) {
      if (this.$(".addnew").length > 0) {
        return;
      }
      if (this.collection.length > 50) {
        $("#tiptip_content").text("You have reached the maximum number of items. (Max 50 items)");
        $(event.currentTarget).tipTip({
          defaultPosition: "left"
        });
        return false;
      }
      $(this.tmplAddNew({
        placeholder: this.placeholder
      })).appendTo(this.$("tbody")).find(".addnew").focus()[0].scrollIntoView();
      this.$("tbody").sortable("disable");
      windowOnResize();
      return true;
    },
    onClickBlank: function() {
      return this.$(":focus").blur();
    },
    onBlurAddnew: function() {
      this.$(".addnew").remove();
      this.$("tbody").sortable("enable");
      return windowOnResize();
    },
    onChangeSelKbd: function(event) {
      var newKbd;
      keys = keyCodes[newKbd = event.currentTarget.value].keys;
      this.collection.trigger("changeKbd", newKbd);
      return this.model.set("kbdtype", newKbd);
    },
    onStartSort: function() {
      return this.$(".ui-sortable-placeholder").next("tr.border").remove();
    },
    onStopSort: function() {
      var target$,
        _this = this;
      $.each(this.$("tbody tr"), function(i, tr) {
        var target$, _ref1, _ref2;
        if (tr.className === "data") {
          if (((_ref1 = $(tr).next("tr")[0]) != null ? _ref1.className : void 0) !== "border") {
            return $(tr).after(_this.tmplBorder);
          }
        } else {
          if (((_ref2 = (target$ = $(tr).next("tr"))[0]) != null ? _ref2.className : void 0) !== "data") {
            return target$.remove();
          }
        }
      });
      if ((target$ = this.$("tbody tr:first"))[0].className === "border") {
        return target$.remove();
      }
    },
    onUpdateSort: function() {
      this.collection.trigger("updateOrder");
      return this.collection.sort();
    },
    decodeKbdEvent: function(value) {
      var keyCombo, keyIdenfiers, modifiers, scanCode;
      modifiers = parseInt(value.substring(0, 2), 16);
      scanCode = value.substring(2);
      keyIdenfiers = keys[scanCode];
      keyCombo = [];
      if (modifiers & 1) {
        keyCombo.push("Ctrl");
      }
      if (modifiers & 2) {
        keyCombo.push("Alt");
      }
      if (modifiers & 8) {
        keyCombo.push("Win");
      }
      if (modifiers & 16) {
        keyCombo.push("MouseL");
      }
      if (modifiers & 32) {
        keyCombo.push("MouseR");
      }
      if (modifiers & 64) {
        keyCombo.push("MouseM");
      }
      if (modifiers & 4) {
        keyCombo.push("Shift");
        keyCombo.push(keyIdenfiers[1] || keyIdenfiers[0]);
      } else {
        keyCombo.push(keyIdenfiers[0]);
      }
      return keyCombo.join(" + ");
    },
    getSaveData: function() {
      this.collection.remove(this.collection.findWhere({
        proxy: this.placeholder
      }));
      return {
        config: this.model.toJSON(),
        keyConfigSet: this.collection.toJSON()
      };
    },
    tmplAddNew: _.template("<tr class=\"addnew\">\n  <td colspan=\"3\">\n    <div class=\"proxy addnew\" tabIndex=\"0\"><%=placeholder%></div>\n  </td>\n  <td></td><td></td><td></td><td class=\"blank\"></td>\n</tr>"),
    tmplBorder: "<tr class=\"border\">\n  <td colspan=\"6\"><div class=\"border\"></div></td>\n  <td></td>\n</tr>",
    template: _.template("<thead>\n  <tr>\n    <th>\n      <div class=\"th_inner\">New <i class=\"icon-arrow-right\"></i> Origin shortcut key</div>\n    </th>\n    <th></th>\n    <th></th>\n    <th>\n      <div class=\"th_inner options\">Options</div>\n    </th>\n    <th>\n      <div class=\"th_inner desc\">Description</div>\n    </th>\n    <th></th>\n    <th><div class=\"th_inner blank\">&nbsp;</div></th>\n  </tr>\n</thead>\n<tbody></tbody>")
  });

  marginBottom = 0;

  resizeTimer = false;

  windowOnResize = function() {
    if (resizeTimer) {
      clearTimeout(resizeTimer);
    }
    return resizeTimer = setTimeout((function() {
      var tableHeight;
      tableHeight = window.innerHeight - document.querySelector(".header").offsetHeight - marginBottom;
      document.querySelector(".fixed-table-container").style.pixelHeight = tableHeight;
      $(".fixed-table-container-inner").getNiceScroll().resize();
      return $(".result_outer").getNiceScroll().resize();
    }), 200);
  };

  fk = chrome.extension.getBackgroundPage().fk;

  saveData = fk.getConfig();

  keyCodes = fk.getKeyCodes();

  scHelp = fk.getScHelp();

  scHelpSect = fk.getScHelpSect();

  startEditing = function() {
    return fk.startEditing();
  };

  endEditing = function() {
    return fk.endEditing();
  };

  $ = jQuery;

  $(function() {
    var bookmarksView, commandInputView, commandsView, headerView, keyConfigSetView;
    headerView = new HeaderView({
      model: new Config(saveData.config)
    });
    headerView.render();
    keyConfigSetView = new KeyConfigSetView({
      model: new Config(saveData.config),
      collection: new KeyConfigSet()
    });
    keyConfigSetView.render(saveData.keyConfigSet);
    bookmarksView = new BookmarksView({});
    commandsView = new CommandsView({});
    commandInputView = new CommandInputView({});
    headerView.on("clickAddKeyConfig", keyConfigSetView.onClickAddKeyConfig, keyConfigSetView);
    headerView.on("changeSelKbd", keyConfigSetView.onChangeSelKbd, keyConfigSetView);
    keyConfigSetView.on("showPopup", bookmarksView.onShowPopup, bookmarksView);
    keyConfigSetView.on("showPopup", commandsView.onShowPopup, commandsView);
    keyConfigSetView.on("showPopup", commandInputView.onShowPopup, commandInputView);
    bookmarksView.on("setBookmark", keyConfigSetView.onSetBookmark, keyConfigSetView);
    commandsView.on("setCommand", keyConfigSetView.onSetCommand, keyConfigSetView);
    commandsView.on("showPopup", commandInputView.onShowPopup, commandInputView);
    commandInputView.on("setCommand", keyConfigSetView.onSetCommand, keyConfigSetView);
    chrome.runtime.onMessage.addListener(function(request, sender, sendResponse) {
      switch (request.action) {
        case "kbdEvent":
          return keyConfigSetView.collection.trigger("kbdEvent", request.value);
        case "saveConfig":
          return fk.saveConfig(keyConfigSetView.getSaveData());
      }
    });
    $(window).on("unload", function() {
      return fk.saveConfig(keyConfigSetView.getSaveData());
    }).on("resize", function() {
      return windowOnResize();
    });
    $(".beta").text("\u03B2");
    return windowOnResize();
  });

}).call(this);
