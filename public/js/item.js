(function ($) { $(function () {
// -----------------------------------------------------------------------------
$.extend($, {
  item: {
    toggle_kept: function (icon) {
      var cont_tag = icon.parent().nextAll('.content');
      
      $.ajax({
        url: '/toggle_keep',
        data: {
          feed: cont_tag.data('feed'),
          id:   cont_tag.data('id'),
          keep: icon.hasClass('ui-icon-radio-off'),
        },//data
        type: 'GET',
        dataType: 'json',
        cache: false,
        beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
        success: function (resp) {
          if (resp.ris == 'ok') {
            icon.toggleClass('ui-icon-heart ui-icon-radio-off');
            cont_tag.parent('.linear_item').toggleClass('kept');
          } else
            alert('Server error!');
        },//success
        complete: function () { icon.show().next().remove(); },
        error: function () { alert('Server error!'); }
      });
    },//toggle_kept
    
    toggle_read: function (icon) {
      var cont_tag = icon.parent().nextAll('.content');
      
      $.ajax({
        url: '/toggle_read',
        data: {
          feed: cont_tag.data('feed'),
          id:   cont_tag.data('id'),
          read: icon.hasClass('ui-icon-star'),
        },//data
        type: 'GET',
        dataType: 'json',
        cache: false,
        beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
        success: function (resp) {
          if (resp.ris == 'ok') {
            icon.toggleClass('ui-icon-star ui-icon-minus');
            cont_tag.parent('.linear_item').toggleClass('unread');
            // $.items.refresh_read(item_tag);
          } else
            alert('Server error!');
        },//success
        complete: function () { icon.show().next().remove(); },
        error: function () { alert('Server error!'); }
      });
    },//toggle_read
    
    edit: function (bt) {
      var cont_tag = bt.parent().prevAll('.content'),
          text     = bt.prev().val();
      
      $.ajax({
        url: '/update_item',
        data: {
          feed: cont_tag.data('feed'),
          id:   cont_tag.data('id'),
          text: text,
        },//data
        type: 'POST',
        dataType: 'json',
        cache: false,
        beforeSend: function () { bt.button('disable').after( $.utils.spinner() ); },
        success: function (resp) {
          if (resp.ris == 'ok') {
            cont_tag.find('div:first').html(text);
            bt.parent().prevAll('.content').andSelf().toggle();
          } else
            alert('Server error!');
        },//success
        complete: function () { bt.button('enable').next().remove(); },
        error: function () { alert('Server error!'); }
      });
    },//edit
    
    comment: function (icon) {
      var cont_tag = icon.parent().next('.content'),
          cmt_tag  = cont_tag.find('.comment span'),
          cmt      = prompt('Insert comment:', cmt_tag.text().trim());
      if (cmt)
        $.ajax({
          url: '/comment',
          data: {
            feed: cont_tag.data('feed'),
            id:   cont_tag.data('id'),
            cmt:  cmt,
          },//data
          type: 'POST',
          dataType: 'json',
          cache: false,
          beforeSend: function () { icon.hide().after( $.utils.spinner('linear') ); },
          success: function (resp) {
            if (resp.ris == 'ok') {
              cmt_tag.text(cmt);
            } else
              alert('Server error!');
          },//success
          complete: function () { icon.show().next().remove(); },
          error: function () { alert('Server error!'); }
        });
    },//comment
  },//item
});

// manage clicks on #item details
$('#item').
  // click on modify
  on('click', 'div.item > .icon.edit', function (ev) {
    $(this).parent().nextAll('.content, .edit_content').toggle();
    
    var edit_tag = $(this).parent().nextAll('.edit_content');
    if (edit_tag.is(':visible'))
      edit_tag.find('textarea').focus();
  }).
  on('click', 'div.item > .icon.cmt',  function (ev) { $.item.comment( $(this) );     }).
  on('click', 'div.item > .icon.kept', function (ev) { $.item.toggle_kept( $(this) ); }).
  on('click', 'div.item > .icon.read', function (ev) { $.item.toggle_read( $(this) ); }).
  on('click', 'a[target="_blank"]',    function (ev) {
    ev.preventDefault();
    // fix target="_blank" firefox bug => force opening in new-tab via popup
    window.open($(this).attr('href'), '_blank');
  });

// // setup forward link
// if ($('body').data('forward_url').length > 0) {
//   $('#item').on('click', 'a[target="_blank"]', function (ev) {
//     ev.preventDefault();
//     $.utils.fw_url( $(this).attr('href') );
//   });
// }//if
// -----------------------------------------------------------------------------
}); })(jQuery);
