/* ---------- 3. The unit (the owner's design: Unit, Family) ---------- */
// Learner state per card, for the unit's word list: Known, Learning n%, or New.
const LEARN=['k','k','k','k','k',71,'k',64,'k',58,'n','n','n','k'];
const learnChip=s=>s==='k'?`<span class="st ok">Known</span>`:s==='n'?`<span class="st none">New</span>`:`<span class="st lrn">Learning ${s}%</span>`;
function notice(reviewed){
 return reviewed
  ?`<div class="notice thanks" role="status">${I('heart','s20')}<div><div class="tBody semi">Thanks for checking this unit</div><div class="tSmall sub">Checked by ${CODE} and 2 others</div></div></div>`
  :`<div class="notice">${I('info','s20')}<div class="tBody">No Telugu speaker has checked this unit yet. If you speak Telugu, please report any mistake you find.</div></div>`;
}
const ubar=`<div class="appbar"><span class="ibtn">${I('back')}</span><span class="abt tTitleM ell">Telugu from English</span><span class="tonal" role="button">${I('review','s18')}Review</span><span class="ibtn">${I('bug')}</span></div>`;
function unitBody({reviewed=false,rude=false}={}){
 if(rude) return `<div class="dpad ucol">
  <div class="uhead"><div class="lvl"><span class="lv">B1</span><span class="tTitleS muted">Beyond the course</span><span class="badge18">18+</span></div>
   <div class="tHeadL">Rude words</div>
   <div class="tBodyL muted">Words to recognise, never to use. Each shows how strong it is. You are never asked to type or say them.</div></div>
  <div class="utiles"><div class="ut"><b>0<small>/40</small></b><span>words known</span></div><div class="ut"><b>0<small>/0</small></b><span>rules known</span></div><div class="ut"><b>0<small>/0</small></b><span>sentences open</span></div></div></div>`;
 return `<div class="dpad ucol">
  <div class="uhead"><div class="lvl"><span class="lv">A1</span><span class="tTitleS muted">Unit 7</span></div>
   <div class="tHeadL">Family</div>
   <div class="tBodyL muted">Words first, then the rules they need. A sentence opens once you know every word and rule in it.</div>
   ${notice(reviewed)}</div>
  <div class="utiles"><div class="ut"><b>9<small>/14</small></b><span>words known</span></div><div class="ut"><b>1<small>/2</small></b><span>rules known</span></div><div class="ut"><b>1<small>/11</small></b><span>sentences open</span></div></div>
  <div class="sechd" data-anchor="8"><span class="tTitleL">1 · Words</span><span class="tSmall muted" style="text-align:end">Known means right on 85% of recent answers</span></div>
  <div class="wlist">${CARDS.map(([t,r,m],i)=>`<div class="wrow" role="button" aria-label="${m}"><span class="w te">${t}</span><span class="m"><span class="tTitleS clamp2">${m}</span><span class="tSmall muted ell">${r}</span></span>${learnChip(LEARN[i])}</div>`).join('')}</div>
 </div>`;
}
const continueFoot=`<div class="foot"><div class="btn f">${I('play')}Continue · 3 new, 8 due</div></div>`;
function unit({overlay='',reviewed=false,scroll='top'}={}){
 return frame(unitBody({reviewed}),{bar:ubar,foot:continueFoot,overlay,scrollTo:scroll});
}
const sheet=(inner,label)=>`<div class="scrim"></div><div class="sheet" role="dialog" aria-label="${label}"><div class="handle"></div>${inner}</div>`;
// The sound-alike warning a learner sees: the rude word hidden unless adult content is on.
const learnerWarn=(kind='speaking')=>kind==='speaking'
 ?`<div class="warn">${I('warn','s20')}<div class="tBody semi">Careful when speaking</div>
    <div class="x tBody">Said slightly wrong, this sounds like a rude word. Keep the short i at the start.</div>
    <div class="hid tSmall">${I('eyeoff','s16')}<span>The rude word shows only with adult content on.</span></div></div>`
 :`<div class="warn">${I('warn','s20')}<div class="tBody semi">Careful when writing</div>
    <div class="x tBody">One vowel sign away from a rude word. Write <span class="te">ి</span> (i) on the first letter, not <span class="te">ె</span> (e).</div>
    <div class="hid tSmall">${I('eyeoff','s16')}<span>The rude word shows only with adult content on.</span></div></div>`;
function learnerCard(){
 const inner=`<div class="cardv">
  <div class="ctop"><span class="tSmall muted">te-04xx · noun · Learning 58%</span><span class="ibtn" aria-label="Play">${I('sound')}</span></div>
  <div class="word te">విధవ</div><div class="rd">vidhava</div><div class="ipa">/ʋid̪ʱaʋa/</div>
  <div class="mean">widow</div>
  ${learnerWarn('speaking')}
 </div>`;
 return unit({overlay:sheet(inner,'Card te-04xx'),scroll:'anchor'});
}

/* ---------- 4. Daily learning: the same warning on the drill card ---------- */
function drill({skill,n,body,act}){
 const top=`<div class="dbar"><span class="ibtn">${I('close')}</span><div class="lp" style="flex:1" role="progressbar" aria-valuemin="0" aria-valuemax="9" aria-valuenow="${n}"><span class="a" style="width:${n/9*100}%"></span><span class="t"></span></div><span class="tLabel muted" style="padding:0 12px 0 8px">${n}/9</span></div>`;
 return frame(`<div class="dpad ucol" style="padding-top:8px"><span class="pill">${skill} · Family</span>${body}</div>`,{bar:top,foot:`<div class="foot">${act}</div>`});
}
const grades=`<div class="tSmall muted" style="text-align:center">How well did you know it?</div><div class="grades"><span class="g again">Again</span><span class="g">Hard</span><span class="g sel">Good</span><span class="g easy">Easy</span></div>`;
function drillSeen(){
 return drill({skill:'Seen words',n:4,body:`<div class="dcard cardv"><div class="word te">విధవ</div><div class="rd">vidhava</div><div class="rulep"></div><div class="mean">widow</div>${learnerWarn('speaking')}</div>`,act:grades});
}
function drillSpoken(){
 return drill({skill:'Spoken words',n:6,body:`<div class="dcard cardv"><div class="tBody muted">Say it in Telugu</div><div class="mean">widow</div><div class="rulep"></div>
  <div class="heard">${I('check','s20')}<span>Heard <span class="te">విధవ</span> (vidhava)</span></div>${learnerWarn('speaking')}</div>`,act:`<div class="btn f">Next</div>`});
}
function drillWritten(){
 return drill({skill:'Written words',n:7,body:`<div class="dcard cardv"><div class="tBody muted">Type it in Telugu</div><div class="mean">widow</div><div class="rulep"></div>
  <div class="typed te">విధవ</div><div class="heard">${I('check','s20')}<span>Right: vidhava</span></div>${learnerWarn('writing')}</div>`,act:`<div class="btn f">Next</div>`});
}

/* ---------- 5. Reviewing a unit (the owner's design: Review a unit) ---------- */
function enrolFirst(){
 const overlay=`<div class="scrim"></div><div class="dlg" role="dialog" aria-label="Turn on reviewing first">
  <div style="display:flex;justify-content:center;color:var(--secondary)">${I('review')}</div>
  <div class="tHeadS" style="text-align:center">Turn on reviewing first</div>
  <div class="tBody muted">Reviewing is for Telugu speakers who check units before they ship. Turn on “Review decks” in Settings and the app makes your rater code. Then come back here.</div>
  <div class="acts2"><span class="btn t">Not now</span><span class="btn t">Open Settings</span></div></div>`;
 return unit({overlay});
}
const RS={ok:['f',I('check','s18')+'Right'],none:['ton',I('check','s18')+'Check'],sug:['sug',I('edit','s18')+'Suggested']};
const rbar=`<div class="rbar"><div class="rtop"><span class="ibtn">${I('close')}</span><div style="min-width:0;flex:1"><div class="tTitleL ell">Review · Family</div><div class="tSmall mono muted">${CODE}</div></div><span class="tTitleM" style="padding-right:8px">12/14</span></div>
 <div class="lp" style="margin:4px 16px 0" role="progressbar" aria-valuemin="0" aria-valuemax="14" aria-valuenow="12"><span class="a" style="width:86%"></span><span class="t"></span></div></div>`;
function reviewBody(){
 return `<div class="dpad ucol" style="padding-top:12px">
  <div class="rinfo">${I('info','s20')}<div class="tBody">Mark each card that is right, or tap it to suggest a change. Nothing is sent until you tap Send review; it goes by mail with your rater code.</div></div>
  <div class="sechd" data-anchor="8"><span class="tTitleM">Words <span class="tSmall muted">14 cards</span></span><span class="tSmall muted">10 right · 2 suggested</span></div>
  <div class="rlist">${CARDS.map(([t,r,m,s])=>`<div class="rrow" role="button" aria-label="${m}. ${ST[s][1]}"><div class="m"><div class="w te ell">${t}</div><div class="tSmall muted ell">${r}</div><div class="tBody clamp2">${m}</div></div>
   <span class="rb e" role="button" aria-label="Suggest a change">${I('edit','s20')}</span><span class="rb ${RS[s][0]}" role="button" aria-label="${s==='ok'?'Looks right':s==='sug'?'Suggestion saved':'Mark as right'}">${RS[s][1]}</span></div>`).join('')}</div>
 </div>`;
}
const reviewFoot=`<div class="foot"><div class="rfoot"><span class="btn o">Sign off · 2 left</span><span class="btn f">${I('send','s20')}Send review</span></div></div>`;
function reviewScreen({overlay='',body=null,count='12/14'}={}){
 return frame(body||reviewBody(),{bar:count===null?'':rbar.replace('12/14',count),foot:reviewFoot,overlay,scrollTo:'anchor'});
}

/* ---------- 6. A card in review ---------- */
function cardSheet(){
 const inner=`<div class="cardv">
  <div class="ctop"><span class="tSmall muted">te-0384 · noun · Suggested</span><span class="ibtn" aria-label="Play">${I('sound')}</span></div>
  <div class="pic" aria-hidden="true">👧</div>
  <div class="word te">కూతురు</div>
  <div class="rd">kūturu</div>
  <div class="ipa">/kuːt̪uru/</div>
  <div class="mean">daughter</div>
  <div class="note">Formally <span class="te">కుమార్తె</span> (kumārte).</div>
  <div class="ex"><div class="t te">మా కూతురు బడికి వెళ్తుంది.</div><div class="tSmall muted">mā kūturu baḍiki veḷtundi.</div><div class="tBodyL muted">Our daughter goes to school.</div></div>
 </div>
 <div class="acts"><div class="btn f">${I('check')}Looks right</div><div class="btn o">${I('edit')}Suggest a change</div></div>`;
 return reviewScreen({overlay:sheet(inner,'Card te-0384')});
}
function suggestSheet(){
 const parts=['Word','Reading','IPA','Meaning','Notes','Example','Picture'];
 const inner=`<div class="tTitleL">Suggest a change</div>
 <div class="tBody muted" style="margin-top:4px"><span class="te">కూతురు</span> · daughter · te-0384</div>
 <div style="margin-top:16px"><div class="flabel">Which part?</div>
  <div class="chips" style="padding:0">${parts.map(p=>`<span class="chip${p==='Notes'?' sel':''}">${p==='Notes'?I('check'):''}${p}</span>`).join('')}</div></div>
 <div class="now" style="margin-top:16px"><div class="tSmall muted">Now</div><div class="tBody">Formally <span class="te">కుమార్తె</span> (kumārte).</div></div>
 <div class="field focus tBodyL" style="margin-top:20px"><span class="lb">Your suggestion</span>Formally <span class="te">కుమార్తె</span> (kumārte). In speech also <span class="te">అమ్మాయి</span> (ammāyi), girl: <span class="te">మా అమ్మాయి</span>, our daughter.<span class="caret"></span></div>
 <div class="field tBodyL" style="margin-top:20px"><span class="lb">Why</span>In speech <span class="te">మా అమ్మాయి</span> is as common.</div>
 <div class="fhelp">Kept on this phone until you send your review.</div>
 <div class="acts2"><span class="btn t">Cancel</span><span class="btn f c">Save</span></div>`;
 return reviewScreen({overlay:sheet(inner,'Suggest a change')});
}

/* ---------- 7. An offensive card ---------- */
const rudeBar=rbar.replace('Review · Family','Review · Rude words').replace('12/14','0/40').replace('width:86%','width:0%');
const rudeFoot=reviewFoot.replace('2 left','40 left');
function rudeScreen(overlay){
 return frame(unitBody({rude:true}),{bar:rudeBar,foot:rudeFoot,overlay});
}
const level=n=>`<span class="meter" aria-hidden="true">${[1,2,3,4].map(i=>`<i class="${i<=n?'on':''}"></i>`).join('')}</span>`;
function rudeCard(){
 const inner=`<div class="cardv">
  <div class="ctop"><span class="tSmall muted">te-09xx · noun · Not reviewed</span><span class="ibtn">${I('sound')}</span></div>
  <div class="word te">వెధవ</div>
  <div class="rd">vedhava</div>
  <div class="ipa">/ʋed̪ʱaʋa/</div>
  <div class="mean">idiot, good-for-nothing</div>
  <div class="facts tBody">
   <span class="k">Level</span><span class="v">${level(2)}Medium</span>
   <span class="k">Type</span><span class="v">Swear</span>
   <span class="k">Among friends</span><span class="v">Can be friendly</span>
   <span class="k">Region</span><span class="v">No note yet</span>
  </div>
  <div class="note">From <span class="te">విధవ</span> (vidhava), widow. Recognition only: you are never asked to type or say it.</div>
 </div>
 <div class="acts"><div class="btn f">${I('chart')}Rate this word</div><div class="btn o">${I('edit')}Suggest a change</div></div>`;
 return rudeScreen(sheet(inner,'Card te-09xx'));
}
function rateSheet(){
 const inner=`<div class="tTitleL">Rate this word</div>
 <div class="tBody muted" style="margin-top:4px"><span class="te">వెధవ</span> · vedhava · idiot, good-for-nothing</div>
 <div class="tTitleM" style="margin-top:20px">How offensive is this word to native speakers in general?</div>
 <div class="scale" role="radiogroup" style="margin-top:12px">${[1,2,3,4,5,6,7,8,9].map(n=>`<span role="radio" aria-checked="${n===4}" class="${n===4?'sel':''}">${n}</span>`).join('')}</div>
 <div class="ends tSmall muted"><span>1 Not at all</span><span>9 Extremely</span></div>
 <div class="tSmall muted" style="margin-top:8px">Not how it feels to you: how native speakers around you hear it.</div>
 <div style="margin-top:20px"><div class="flabel">Where you speak Telugu</div>
  <div class="chips" style="padding:0"><span class="chip">Telangana</span><span class="chip sel">${I('check')}Coastal Andhra</span><span class="chip">Rayalaseema</span><span class="chip">Elsewhere</span></div></div>
 <div style="margin-top:16px"><div class="flabel">Can it be friendly among friends?</div>
  <div class="chips" style="padding:0"><span class="chip sel">${I('check')}Yes</span><span class="chip">No</span><span class="chip">Sometimes</span></div></div>
 <div class="acts2 split"><span class="btn t">${I('edit','s18')}Suggest a change</span><span class="btn f c">Save</span></div>`;
 return rudeScreen(sheet(inner,'Rate this word'));
}

/* ---------- 8. A sound-alike pair in review ---------- */
function alikeReview(){
 const inner=`<div class="cardv">
  <div class="ctop"><span class="tSmall muted">te-04xx · noun · Not reviewed</span><span class="ibtn">${I('sound')}</span></div>
  <div class="word te">విధవ</div><div class="rd">vidhava</div><div class="ipa">/ʋid̪ʱaʋa/</div><div class="mean">widow</div>
  <div class="warn">${I('warn','s20')}<div class="tBody semi">Sounds like <span class="te">వెధవ</span> (vedhava)</div>
   <div class="x tBody">A medium swear, one vowel apart. Found by the sound check.</div></div>
  <div style="align-self:stretch;text-align:start;margin-top:4px"><div class="flabel">Is this a real risk?</div>
   <div class="seg" role="radiogroup"><span class="sel" role="radio" aria-checked="true">${I('check','s18')}Confirm</span><span role="radio" aria-checked="false">Reject</span></div></div>
  <div style="align-self:stretch;text-align:start;margin-top:8px"><div class="field focus tBodyL" style="background:var(--sLow)"><span class="lb">Care note</span>Keep the short i at the start.<span class="caret"></span></div>
   <div class="fhelp"><span>Learners see this. Short and plain.</span><span>30/40 letters</span></div></div>
 </div>
 <div class="acts2"><span class="btn t">Cancel</span><span class="btn f c">Save</span></div>`;
 return reviewScreen({overlay:sheet(inner,'Card te-04xx')});
}

/* ---------- 9. Sending ---------- */
function confirmSend(){
 const overlay=`<div class="scrim"></div><div class="dlg" role="dialog" aria-label="Send review">
  <div class="tHeadS">Send 12 reviews of Family by mail?</div>
  <div class="tBody muted">Your mail app opens with the review attached. Send it from the mail address you always use. From any other mail address, a review with your code is held back until the Fluenough team checks it.</div>
  <div class="acts2"><span class="btn t">Cancel</span><span class="btn t">Send</span></div></div>`;
 return reviewScreen({overlay});
}
function gmail(){
 const body=`<div class="grow"><span class="k">From</span><span class="v ell">aro.k@gmail.com</span><span class="ibtn" style="width:40px;height:40px">${I('down')}</span></div>
  <div class="grow"><span class="k">To</span><span class="v"><span class="gchip"><span class="gav">F</span><span class="ell tBody">Fluenough</span></span></span><span class="ibtn" style="width:40px;height:40px">${I('down')}</span></div>
  <div class="grow"><span class="gsubj">[Fluenough review] ${CODE} (te)</span></div>
  <div class="gbody">
   <div>12 reviews of ${DECK}, from Fluenough 0.3.4.</div>
   <div class="muted">Rater code ${CODE}. Please send without changing the file.</div>
   <div class="att"><span class="fi">${I('file','s20')}</span><span style="min-width:0"><div class="tBody ell">${DECK}-review.json</div><div class="tSmall muted">4 KB</div></span><span class="ibtn">${I('close','s20')}</span></div>
  </div>`;
 return {cls:'gm',html:`<div class="sbar"><span>9:41</span><span class="ic"><i></i><i></i><i style="width:20px"></i></span></div>
  <div class="gbar"><span class="ibtn">${I('back')}</span><span class="gt">Compose</span><span class="ibtn">${I('attach')}</span><span class="ibtn send" aria-label="Send">${I('send')}</span><span class="ibtn">${I('more')}</span></div>
  <div class="scroll">${body}</div>`};
}
const issue=`<div class="issue" role="img" aria-label="The public issue">
 <div class="ih"><div class="it" style="white-space:nowrap">Review: ${CODE} (te)</div><div style="color:var(--page-muted);margin-top:-4px">#412</div>
  <div class="lbls"><span class="lbl">review</span><span class="lbl">lang: te</span></div></div>
 <div class="ib"><div>A review came by mail.</div>
  <dl><dt>Rater code</dt><dd>${CODE}</dd><dt>Language</dt><dd>te (Telugu)</dd></dl>
  <div style="color:var(--page-muted)">The reviews themselves stay in the mail.</div></div>
 <div class="if">Opened by the hourly mail workflow. No suggestion text, no mail address.</div></div>`;

/* ---------- 10. Thank you ---------- */
function unitThanks(){ return unit({reviewed:true}); }

/* ---------- Layout ---------- */
const SCREENS=[
 {t:'1. Settings: becoming a reviewer',w:'Everyone sees "Review decks" and "How reviewing works". Turning reviewing on asks once, then shows the rater code the phone made (FL-XXXX-XXXX-C, Crockford base32 with a check character), with Copy, and opens "How reviewing works" by itself, that one time. The same switch turns reviewing off and keeps the code. Everywhere else the app names this switch "Review decks" too.',
  s:[['Off',()=>settings('off')],['Turning on',()=>settings('ask')],['Just turned on: shown once',()=>settings('on',howSheet())],['On: the code',()=>settings('on')]]},
 {t:'2. How reviewing works',w:'One sheet explains reviewing in five steps, in the order it happens. It opens by itself once, right after turning reviewing on, and again whenever the reviewer taps "How reviewing works" in Settings, with reviewing on or off. It is a scroll-controlled bottom sheet with a drag handle, as the app\'s other long sheets are (the report sheet): the text scrolls under the title, and Got it stays in place.',
  s:[['Opened from Settings',()=>settings('off',howSheet())],['Scrolled to the end',()=>settings('off',howSheet(true))]]},
 {t:'3. The unit, and a card in it',w:'The owner\'s Unit design: the level and unit number, what the unit teaches, words, rules and sentences known, then the words, each Known, Learning or New. The "not yet checked" notice sits under the description. Review is at the top right. Tapping a word opens its card; a word with a sound-alike shows the warning, the rude word hidden unless adult content is on.',
  s:[['The unit',()=>unit()],['A card, adult content off',()=>learnerCard()]]},
 {t:'4. Daily learning: the warning on the drill card',w:'The same warning shows on the drill card once the word is shown or answered, never before, so it gives nothing away: seen words after the answer is revealed, spoken words after the app heard it, written words after it was typed. Sound-alikes warn when speaking, look-alikes when writing. The skill names are the learner\'s: seen, heard, spoken and written words.',
  s:[['Seen words',()=>drillSeen()],['Spoken words',()=>drillSpoken()],['Written words, a look-alike',()=>drillWritten()]]},
 {t:'5. Reviewing a unit',w:'The owner\'s Review design. With reviewing off, Review explains and points to Settings. With it on, Review opens the unit\'s cards with the rater code and how far the review has got. Each card has Suggest a change (the pencil) and Right; a card not yet marked shows Check. Sign off becomes possible once every card is marked; Send review sends what is marked so far.',
  s:[['Reviewing off',()=>enrolFirst()],['Reviewing on',()=>reviewScreen()]]},
 {t:'6. A card in review',w:'Tapping a card opens it in a sheet, laid out as a lesson shows it (picture, word, reading, IPA, meaning, notes, example), with Looks right and Suggest a change. A suggestion picks the part, shows what it says now, and asks for the change and why.',
  s:[['The card',()=>cardSheet()],['Suggest a change',()=>suggestSheet()]]},
 {t:'7. An offensive card (adult content on)',w:'Rude words are a unit of their own under "Beyond the course", marked 18+. A card shows its level, type, whether it can be friendly among peers and its region note. The reviewer rates it 1 to 9 on the research\'s question and says where they speak the language; the regions come from the course, and a disagreement between regions becomes the card\'s region note.',
  s:[['The card and its level',()=>rudeCard()],['Rating',()=>rateSheet()]]},
 {t:'8. A sound-alike pair in review',w:'With adult content on, the reviewer sees the word the check found, confirms or rejects the pair, and writes the care note learners read: at most 40 letters, counted as they type.',
  s:[['Confirm and write the care note',()=>alikeReview()]]},
 {t:'9. Sending',w:'One confirm, which repeats the rule from step 3 of "How reviewing works" (always send from the same mail address), then the reviewer\'s own mail app opens (Android share, ACTION_SEND) with the Fluenough address, the subject with the rater code and language, and the file. The public issue the workflow opens names only the rater code and language, so the owner knows to read the mail.',
  s:[['Confirm',()=>confirmSend()],['The mail app',()=>gmail()]],extra:['The public issue',issue]},
 {t:'10. Thank you',w:'When an updated unit lists the reviewer\'s code, the unit says thank you where the "not yet checked" notice was, and Settings lists the units they helped build.',
  s:[['The unit',()=>unitThanks()],['Settings',()=>settings('thanks')]]}
];
