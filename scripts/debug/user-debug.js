// DEBUG HARNESS ONLY — evaluates code posted to the frame. Never leave installed.
(function(){
  if (window.__rmdbg) return; window.__rmdbg = 1;
  var say = function(m){ try { window.webkit.messageHandlers.rmweb.postMessage('['+location.host.slice(0,22)+(window.top===window?' TOP':' sub')+'] '+m); } catch(e){} };
  ['keydown','touchstart','touchend','pointerdown','pointerup','mousedown','mouseup','click'].forEach(function(t){
    window.addEventListener(t, function(e){ say('ev '+t+' key='+(e.key||'')+' trusted='+e.isTrusted+' tgt='+(e.target&&e.target.tagName)+' xy='+(e.clientX|0)+','+(e.clientY|0)); }, true);
  });
  window.addEventListener('message', function(e){
    var d = e.data; if (!d || typeof d !== 'object' || !d.rmwebEval) return;
    try { say('eval -> ' + String((0,eval)(d.rmwebEval)).slice(0,600)); } catch(x){ say('eval ERR '+x); }
    for (var i=0;i<frames.length;i++) frames[i].postMessage(d,'*');
  });
  say('loaded frames='+frames.length+' focus='+document.hasFocus()+' size='+innerWidth+'x'+innerHeight);
})();
