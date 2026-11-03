// ==UserScript==
// @name         Add StashID to Whisparr
// @namespace    http://tampermonkey.net/
// @version      2024-10-15
// @description  Add a StashDB scene to your local Whisparr instance.
// @author       randybudweiser
// @match        https://stashdb.org/scenes/*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=tampermonkey.net
// @grant        none
// ==/UserScript==

// Local adaptation of randybudweiser/stash2whisparr (MIT). The Whisparr API
// answers stashdb.org with Access-Control-Allow-Origin: *, so plain fetch
// works without a userscript manager grant.

const scheme = "https";
const userDomain = "whisparr.jadee.fyi";
// sops: mini/media/whisparr/api-key. Replace before (or after) importing.
const apiKey = "REPLACE_WITH_WHISPARR_API_KEY";
const quality = "1"; // the first quality profile, "Local (No Upgrade)"
const rootFolderPath = "/stuff";
const apiBase = `${scheme}://${userDomain}/api/v3`;

(function () {
  'use strict';

  const triggerButton = document.createElement('button');
  triggerButton.textContent = 'Add scene to Whisparr';
  triggerButton.style.cssText =
    'position:fixed;top:56px;left:12px;z-index:1000;padding:10px;' +
    'border:0;border-radius:5px;cursor:pointer;background:#e385ed;color:#fff';
  document.body.appendChild(triggerButton);

  triggerButton.addEventListener('click', async () => {
    const sceneID = window.location.pathname.split('/scenes/')[1]?.split('/')[0];
    if (!sceneID) {
      window.alert('No StashDB scene id in the URL.');
      return;
    }
    try {
      const lookup = await fetch(
        `${apiBase}/lookup/scene?term=${encodeURIComponent(sceneID)}`,
        { headers: { Accept: '*/*', 'X-Api-Key': apiKey } }
      );
      if (!lookup.ok) throw new Error(await lookup.text());
      const [hit] = await lookup.json();
      if (!hit || !hit.movie) throw new Error('scene not found in Whisparr metadata');

      const movie = hit.movie;
      const body = {
        title: movie.title,
        year: movie.year || 0,
        foreignId: hit.foreignId,
        stashId: hit.foreignId,
        qualityProfileId: Number(quality),
        rootFolderPath,
        monitored: true,
        addOptions: { monitor: 'movieOnly', searchForMovie: true },
      };
      const added = await fetch(`${apiBase}/movie`, {
        method: 'POST',
        headers: {
          Accept: '*/*',
          'X-Api-Key': apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      });
      const text = await added.text();
      if (!added.ok) throw new Error(text);
      window.alert(`Requested in Whisparr: ${movie.title}`);
    } catch (error) {
      console.error(error);
      window.alert(`Whisparr: ${error.message}`);
    }
  });
})();
