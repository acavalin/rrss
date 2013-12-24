(function ($) { $(function () {
// -----------------------------------------------------------------------------
$.extend($, {
  feeds: {
    update_folder_unread_count: function () {
      $('#feeds div.folder').each(function () {
        var sum = 0;
        $(this).next().find('div.feed .unread').
          each(function () { sum += parseInt($(this).text().trim() || 0); });
        $(this).find('.unread').text(sum == 0 ? '' : sum);
      });
    },//update_folder_unread_count
    
    show_logs: function () {
      $.ajax({
        url: '/logs',
        type: 'GET',
        dataType: 'html',
        cache: false,
        beforeSend: function () { $('#item').html($.utils.spinner('bigmsg')); },
        success: function (resp) { $('#item').html(resp); },
        error: function () { $('#item').html('Server error!'); }
      });
    },//show_logs
    
    show_help: function () {
      $.ajax({
        url: '/help.htm',
        type: 'GET',
        dataType: 'html',
        cache: false,
        beforeSend: function () { $('#item').html($.utils.spinner('bigmsg')); },
        success: function (resp) { $('#item').html(resp); },
        error: function () { $('#item').html('Server error!'); }
      });
    },//show_help

    refresh_title: function () {
      // save original window title
      if (!$('body').data('title'))
        $('body').data('title', document.title);

      // show unread counter on window title
      var sum = 0;
      $('#feeds div.feed .unread').
        each(function () { sum += parseInt($(this).text().trim() || 0); });
      document.title = sum == 0 ? $('body').data('title') : 'RRSS ('+sum+' unread)';
    },//refresh_title
    
    refresh_feeds: function () {
      var feed_name = $('#feeds div.item.selected').data('name');
      
      $.ajax({
        url: '/feeds',
        type: 'GET',
        dataType: 'html',
        cache: false,
        beforeSend: function () {
          var label = $('#feeds div.item.root span:first');
          if (label.find('img').length == 0)
            label.append(' ' + $.utils.spinner('linear'));
        },//beforeSend
        success: function (resp) {
          $('#feeds').html(resp);
          $.utils.fix_toolbars_width( $('#feeds > div.root') );
          $.feeds.update_folder_unread_count();
          
          if (feed_name)  // evidenzia la voce precedente
            $('#feeds div.item[data-name="'+feed_name+'"]').
              addClass('selected').
              parents('.folder_contents').show();

          $.feeds.refresh_title();
        },//success
        error: function () { $('#feeds').html('Server error!'); }
      });
    },//refresh_feeds
    
    purge_items: function (feed_tag) {
      var name = $(feed_tag).data('name'),
          icon = feed_tag.find('.icon.purge');
      if (confirm('Purge unkept items for '+name+'?'))
        $.ajax({
          url: '/purge_feed',
          data: { feed: name },
          type: 'GET',
          dataType: 'json',
          cache: false,
          beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
          success: function (resp) {
            if (resp.ris == 'ok') {
              feed_tag.find('.unread').text(resp.unread == 0 ? '' : resp.unread);
              $.feeds.update_folder_unread_count();
              feed_tag.toggleClass('unread', resp.unread > 0);
              if (feed_tag.hasClass('selected'))
                feed_tag.click();
            } else
              alert('Server error!');
          },//success
          complete: function () { icon.show().next().remove(); },
          error: function () { alert('Server error!'); }
        });
    },//purge_items
    
    load_items: function (feed_tag, options) {
      var names = $.makeArray(
        ( feed_tag.hasClass('feed') ? feed_tag : feed_tag.next().find('div.feed') ).
          map(function () { return $(this).data('name'); })
      );
      
      options = $.extend({
        filter: 0,
        search: '',
      }, options || {});
      
      $.ajax({
        url: '/items',
        data: $.extend({
          feeds: names,
          container: feed_tag.find('.name').text(),
        }, options),
        type: 'GET',
        dataType: 'html',
        cache: false,
        beforeSend: function () { $('#items').html($.utils.spinner('bigmsg')); },
        success: function (resp) {
          $('#items').
            data('feeds', names).
            data('search', {feeds: names, term: options.search}).  // save last search
            html(resp);
          $.utils.fix_toolbars_width( $('#items > div.root') );
        },//success
        error: function () { $('#items').html('Server error!'); }
      });
    },//load_items
  },//feeds
});

// caricamento e refresh della lista dei feeds
$.feeds.refresh_feeds();
setInterval(function () { $.feeds.refresh_feeds(); }, $.config.feeds_refresh_time * 60 * 1000);

// gestione click sui feeds
$('#feeds').
  // click su apertura/chisura folder
  on('click', 'div.folder > .icon.folder', function (ev) {
    $(this).toggleClass('ui-icon-folder-collapsed ui-icon-folder-open');
    $(this).parent().next().slideToggle('fast');
  }).
  // click su un folder/feed
  on('click', 'div.item', function (ev) {
    if (!$(ev.target).is('.ui-icon-extlink, .ui-icon-folder-collapsed, .ui-icon-folder-open, .ui-icon-trash') &&
        !$(this).hasClass('root')) {
      // evidenzia riga
      $('#feeds div.item.selected').removeClass('selected');
      $(this).addClass('selected');
      
      $.feeds.load_items( $(this) );
    }//if
  }).
  // click su purge items
  on('click', 'div.item > .purge', function (ev) {
    $.feeds.purge_items( $(this).parent() );
  });
// -----------------------------------------------------------------------------
}); })(jQuery);
