/* Vanguard's Descent save bridge.
   The game calls window.VDSave to load and save JSON documents.
   Shared mode: Firestore, under the same passphrase-keyed campaign path Session Scribe uses
   (campaigns/<sha256('table-notes:' + passphrase)>/<collection>/<id>).
   Local mode: this browser's localStorage, used when no passphrase is stored or Firestore is unreachable.
   Every shared save is also mirrored locally so an outage never loses a run. */
(function () {
  var LS_PASS = 'table-notes-pass', LS_PREFIX = 'vd:';
  var mode = 'local', base = null, ready = null;
  function ls(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) {} return null; }
  function init() {
    if (ready) return ready;
    ready = new Promise(function (resolve) {
      var cfg = window.TABLE_NOTES_FIREBASE, pass = ls(LS_PASS);
      if (!cfg || !pass || !window.firebase || !(window.crypto && crypto.subtle)) return resolve();
      crypto.subtle.digest('SHA-256', new TextEncoder().encode('table-notes:' + pass)).then(function (buf) {
        var key = Array.prototype.map.call(new Uint8Array(buf), function (b) { return ('0' + b.toString(16)).slice(-2); }).join('');
        if (!firebase.apps.length) firebase.initializeApp(cfg);
        base = firebase.firestore().collection('campaigns').doc(key);
        mode = 'shared'; resolve();
      }, function () { resolve(); });
    });
    return ready;
  }
  function call(cb) { var a = Array.prototype.slice.call(arguments, 1); try { cb.apply(null, a); } catch (e) { console.error('VDSave callback', e); } }
  window.VDSave = {
    mode: function () { return mode; },
    hasPassphrase: function () { return !!ls(LS_PASS); },
    /* cb(jsonStringOrNull) */
    loadDoc: function (coll, id, cb) {
      init().then(function () {
        var local = ls(LS_PREFIX + coll + '/' + id);
        if (mode !== 'shared') return call(cb, local);
        base.collection(coll).doc(id).get().then(function (snap) {
          call(cb, snap.exists ? JSON.stringify(snap.data()) : local);
        }, function (err) { console.warn('VDSave load failed, using local copy', err); mode = 'local (database unreachable)'; call(cb, local); });
      });
    },
    /* cb(ok, errorMessage) */
    saveDoc: function (coll, id, json, cb) {
      init().then(function () {
        ls(LS_PREFIX + coll + '/' + id, json);
        if (mode !== 'shared') return call(cb, true, '');
        base.collection(coll).doc(id).set(JSON.parse(json)).then(function () { call(cb, true, ''); },
          function (err) { console.warn('VDSave save failed, kept local copy', err); call(cb, false, String(err && err.message || err)); });
      });
    }
  };
  init();
})();
