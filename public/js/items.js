(function ($) { $(function () {
// -----------------------------------------------------------------------------
$.extend($, {
  items: {
    toggle_kept: function (item_tag) {
      var name = item_tag.data('feed'),
          id   = item_tag.data('id'),
          icon = item_tag.find('.icon.kept');
      
      $.ajax({
        url: '/toggle_keep',
        data: {
          feed: name,
          id:   id,
          keep: icon.hasClass('ui-icon-radio-off'),
        },//data
        type: 'GET',
        dataType: 'json',
        cache: false,
        beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
        success: function (resp) {
          if (resp.ris == 'ok') {
            icon.toggleClass('ui-icon-heart ui-icon-radio-off');
            item_tag.toggleClass('kept');
          } else
            alert('Server error!');
        },//success
        complete: function () { icon.show().next().remove(); },
        error: function () { alert('Server error!'); }
      });
    },//toggle_kept
    
    toggle_read: function (item_tag) {
      var name = item_tag.data('feed'),
          id   = item_tag.data('id'),
          icon = item_tag.find('.icon.read');
      
      $.ajax({
        url: '/toggle_read',
        data: {
          feed: name,
          id:   id,
          read: item_tag.hasClass('unread'),
        },//data
        type: 'GET',
        dataType: 'json',
        cache: false,
        beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
        success: function (resp) {
          if (resp.ris == 'ok') {
            icon.toggleClass('ui-icon-star ui-icon-minus');
            item_tag.toggleClass('unread');
            $.items.refresh_read(item_tag);
          } else
            alert('Server error!');
        },//success
        complete: function () { icon.show().next().remove(); },
        error: function () { alert('Server error!'); }
      });
    },//toggle_read
    
    // update GUI uread counters starting from "item_tag"
    refresh_read: function (item_tag) {
      var icon      = item_tag.find('.icon.read'),
          counter   = $('#feeds div.feed[data-name="'+item_tag.data('feed')+'"] .unread'),
          cur_value = parseInt(counter.text() || 0),
          is_unread = item_tag.hasClass('unread'),
          increment = is_unread ? 1 : -1;
      
      // update feed unread counter
      icon.toggleClass('ui-icon-star',  is_unread );
      icon.toggleClass('ui-icon-minus', !is_unread);
      cur_value += increment;
      if (cur_value > 0)
        counter.text(cur_value).parent().addClass('unread');
      else
        counter.text('').parent().removeClass('unread');
      
      // update the eventual folder unread counters
      counter.parent().parents('.folder_contents').prev('.folder').find('.unread').each(function () {
        var counter = $(this),
            cur_value = parseInt(counter.text() || 0) + increment;
        counter.text(cur_value > 0 ? cur_value : '');
      });

      $.feeds.refresh_title();
    },//refresh_read
    
    load_item: function (item_tag) {
      var name = item_tag.data('feed'),
          id   = item_tag.data('id');
      
      $.ajax({
        url: '/item',
        data: {
          feed: name,
          id:   id,
        },//data
        type: 'GET',
        dataType: 'html',
        cache: false,
        beforeSend: function () { $('#item').html($.utils.spinner('bigmsg')); },
        success: function (resp) {
          $('#item').
            data('feed', name).
            html(resp);
          
          $('#item a').attr('target', '_blank');
          
          $.utils.fix_toolbars_width( $('#item > div.root') );
          
          // move contents below the control bar
          var tbar_height = $('#item > div.root').height() + 10;
          $('#item > div.content, #item > div.edit_content').
            css('margin-top', tbar_height +'px');
          
          // mark item as read
          if (item_tag.hasClass('unread')) {
            item_tag.removeClass('unread');
            $.items.refresh_read(item_tag);
          }//if

          // set the focus on the first item in order to use PgUp/PgDw
          $('#item .content:first').attr('tabindex', 1000).focus();
        },//success
        error: function () { $('#item').html('Server error!'); }
      });
    },//load_item
    
    // filters descriptions
    filters: [ 'unread + kept', 'unread', 'kept', 'all' ],
    
    next_filter: function () {
      var feed_item   = $('#feeds .selected'),
          next_filter = ( $('#items div.root').data('cur_filter') || 0 ) + 1;
      
      if (next_filter > 3)
        next_filter = 0;
      
      if (feed_item.length != 0)
        $.feeds.load_items(feed_item, {filter: next_filter});
    },//next_filter
    
    mark_all_read: function () {
      var icon = $('#items div.root .icon.mark_all_read .ui-icon');
      
      if (icon.length > 0 && confirm('Mark all read?')) {
        var ids = {};
        // extract only visible ids
        $( $('#items').data('feeds') ).each(function () {
          ids[ this ] = $.makeArray(
            $('#items div.item[data-id][data-feed="'+this+'"]').
              map(function () { return $(this).data('id'); })
          );
        });
        
        $.ajax({
          url: '/mark_all_read',
          data: {
            feeds: $('#items').data('feeds'),
            ids:   ids
          },
          type: 'POST',
          dataType: 'json',
          cache: false,
          beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
          success: function (resp) {
            if (resp.ris == 'ok') {
              $('#items div.item.unread:not(.toolbar), #item div.linear_item.unread').
                removeClass('unread').
                find('.icon.read').toggleClass('ui-icon-star ui-icon-minus');
              $.feeds.refresh_feeds();
            } else
              alert('Server error!');
          },//success
          complete: function () { icon.show().next().remove(); },
          error: function () { alert('Server error!'); }
        });
      }//if
    },//mark_all_read
    
    close_view: function () {
      $('#feeds div.selected').removeClass('selected');
      $('#item, #items').empty();
      $('#items').data('feeds', null);
      $('#items').data('search', null);
    },//close_view
    
    linear_view: function (thumbs) {
      var names  = $('#items').data('feeds'),
          search = $('#items').data('search');  // get last search
      
      if (names && names.length > 0) {
        $.ajax({
          url: '/items',
          data: {
            feeds: names,
            linear: true,
            filter: $('#items div.root').data('cur_filter'),
            // filter results if the search is on the current feeds list  
            search: names == search.feeds ? search.term : '',
          },//data
          type: 'GET',
          dataType: 'html',
          cache: false,
          beforeSend: function () { $('#item').html( $.utils.spinner('bigmsg') ); },
          success: function (resp) {
            $('#item').html(resp);
            
            if (thumbs)
              $('#item .linear_item').addClass('inline_item');
            
            $('#item a').attr('target', '_blank');
            
            // set the focus on the first item in order to use PgUp/PgDw
            $('#item .linear_item:first .content').attr('tabindex', 1000).focus();
          },//success
          error: function () { $('#item').html('Server error!'); }
        });
      }//if
    }//linear_view
  },//items
});


// scroll #items to the selected item
$.fn.scroll_items_here = function () {
  if ($(this).length != 0)
    $('#items').scrollTop(
      $('#items').scrollTop() +
      $(this).first().offset().top -
      $('#items div.root').height() * 2
    );
}//scroll_items_here


// manage clicks on #items child elements
$('#items').
  // click on folder/feed
  on('click', 'div.item', function (ev) {
    if (!$(ev.target).is('.ui-icon-heart, .ui-icon-radio-off, .ui-icon-star, .ui-icon-minus') &&
        !$(this).hasClass('root')) {
      // highlight row
      $('#items div.item.selected').removeClass('selected');
      $(this).addClass('selected');
      
      $.items.load_item( $(this) );
    }//if
  }).
  on('click', 'div.item > .icon.kept',          function (ev) { $.items.toggle_kept( $(this).parent() ); }).
  on('click', 'div.item > .icon.read',          function (ev) { $.items.toggle_read( $(this).parent() ); }).
  on('click', 'div.item > .icon.filter',        function (ev) { $.items.next_filter();                   }).
  on('click', 'div.item > .icon.linear_view',   function (ev) { $.items.linear_view();                   }).
  on('click', 'div.item > .icon.close_view',    function (ev) { $.items.close_view();                    }).
  on('click', 'div.item > .icon.mark_all_read', function (ev) { $.items.mark_all_read();                 });
// -----------------------------------------------------------------------------
}); })(jQuery);
