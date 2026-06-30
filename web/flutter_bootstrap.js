{{flutter_js}}
{{flutter_build_config}}

(function () {
  var loadingEl = document.getElementById('app-loading');
  var errorEl = document.getElementById('app-error');

  function hideLoading() {
    if (loadingEl) loadingEl.style.display = 'none';
  }

  function showError(msg) {
    hideLoading();
    if (errorEl) {
      errorEl.innerHTML = msg;
      errorEl.style.display = 'flex';
    }
  }

  // Если Flutter не инициализировался за 30 секунд — показываем ошибку
  var timeoutId = setTimeout(function () {
    showError(
      '<div style="text-align:center;padding:24px;font-family:sans-serif">' +
      '<div style="font-size:48px;margin-bottom:12px">⚠️</div>' +
      '<div style="font-size:18px;font-weight:bold;color:#c62828;margin-bottom:8px">Не удалось загрузить приложение</div>' +
      '<div style="color:#555;margin-bottom:16px">Проверьте соединение с интернетом и обновите страницу</div>' +
      '<button onclick="location.reload()" style="background:#c62828;color:#fff;border:none;padding:12px 24px;border-radius:8px;font-size:16px;cursor:pointer">Обновить</button>' +
      '</div>'
    );
  }, 30000);

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        var appRunner = await engineInitializer.initializeEngine();
        clearTimeout(timeoutId);
        hideLoading();
        await appRunner.runApp();
      } catch (e) {
        clearTimeout(timeoutId);
        console.error('Flutter engine init failed:', e);
        showError(
          '<div style="text-align:center;padding:24px;font-family:sans-serif">' +
          '<div style="font-size:48px;margin-bottom:12px">⚠️</div>' +
          '<div style="font-size:18px;font-weight:bold;color:#c62828;margin-bottom:8px">Ошибка загрузки</div>' +
          '<div style="color:#555;margin-bottom:8px">Попробуйте обновить страницу</div>' +
          '<div style="font-size:11px;color:#999;margin-bottom:16px">' + (e.message || e) + '</div>' +
          '<button onclick="location.reload()" style="background:#c62828;color:#fff;border:none;padding:12px 24px;border-radius:8px;font-size:16px;cursor:pointer">Обновить</button>' +
          '</div>'
        );
      }
    }
  });
})();
