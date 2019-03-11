function attach_event_handler(name, url) {
  var $checkbox = $('.settings #' + name + '-input');

  $checkbox.on('change', function () {
    var val = $checkbox.prop('checked');
    console.log(name, val);

    var params = {};
    params[name] = val;
    $.ajax({url: url, method: 'PATCH', data: params})
        .done(function (res) {
          console.log(res);
        })
        .fail(function (xhr) {
          console.log(xhr.responseText);
        });
  });
}

var Settings = {};

Settings.enableDeleteTweetsButton = function () {
  var $modal = $('#delete-tweets-modal');
  $modal.find('.ok').on('click', function (e) {
    $modal.modal('hide');
    $('.delete-tweets-btn').attr('disabled', 'disabled')
        .prop("disabled", true);
    $.post($(this).data('url'), function (res) {
      console.log(res);
    });
  });
};

Settings.enableResetEgotterButton = function () {
  var $modal = $('#reset-egotter-modal');
  $modal.find('.ok').on('click', function (e) {
    $modal.modal('hide');
    $('.reset-egotter-btn').attr('disabled', 'disabled')
        .prop("disabled", true);
    $.post($(this).data('url'), function (res) {
      console.log(res);
    });
  });
};

Settings.enableResetCacheButton = function () {
  var $modal = $('#reset-cache-modal');
  $modal.find('.ok').on('click', function (e) {
    $modal.modal('hide');
    $('.reset-cache-btn').attr('disabled', 'disabled')
        .prop("disabled", true);
    $.post($(this).data('url'), function (res) {
      console.log(res);
    });
  });
};

Settings.enableUpdateProfileButton = function (callback, errorCallback) {
  $('.update-profile').on('click', function (e) {
    e.preventDefault();
    var $clicked = $(this);
    $.post($clicked.data('url'))
        .done(function (res) {
          console.log(res);
          if (callback) {
            callback(res);
          }
        })
        .fail(function (xhr) {
          console.log(xhr.responseText);
          if (xhr.responseText) {
            if (errorCallback) {
              errorCallback(JSON.parse(xhr.responseText));
            }
          }
        });
    {

    }
    ;
    return false;
  });
};
