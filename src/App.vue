<script setup>
import { computed, nextTick, ref, watch } from 'vue'

const groups = [
  { row: 'あ', type: 'clear', hira: 'あいうえお', kata: 'アイウエオ', roma: ['a','i','u','e','o'] },
  { row: 'か', type: 'clear', hira: 'かきくけこ', kata: 'カキクケコ', roma: ['ka','ki','ku','ke','ko'] },
  { row: 'さ', type: 'clear', hira: 'さしすせそ', kata: 'サシスセソ', roma: ['sa','shi','su','se','so'] },
  { row: 'た', type: 'clear', hira: 'たちつてと', kata: 'タチツテト', roma: ['ta','chi','tsu','te','to'] },
  { row: 'な', type: 'clear', hira: 'なにぬねの', kata: 'ナニヌネノ', roma: ['na','ni','nu','ne','no'] },
  { row: 'は', type: 'clear', hira: 'はひふへほ', kata: 'ハヒフヘホ', roma: ['ha','hi','fu','he','ho'] },
  { row: 'ま', type: 'clear', hira: 'まみむめも', kata: 'マミムメモ', roma: ['ma','mi','mu','me','mo'] },
  { row: 'や', type: 'clear', hira: 'やゆよ', kata: 'ヤユヨ', roma: ['ya','yu','yo'] },
  { row: 'ら', type: 'clear', hira: 'らりるれろ', kata: 'ラリルレロ', roma: ['ra','ri','ru','re','ro'] },
  { row: 'わ', type: 'clear', hira: 'わをん', kata: 'ワヲン', roma: ['wa','wo','n'] },
  { row: 'が', type: 'voiced', hira: 'がぎぐげご', kata: 'ガギグゲゴ', roma: ['ga','gi','gu','ge','go'] },
  { row: 'ざ', type: 'voiced', hira: 'ざじずぜぞ', kata: 'ザジズゼゾ', roma: ['za','ji','zu','ze','zo'] },
  { row: 'だ', type: 'voiced', hira: 'だぢづでど', kata: 'ダヂヅデド', roma: ['da','ji|di','zu|du','de','do'] },
  { row: 'ば', type: 'voiced', hira: 'ばびぶべぼ', kata: 'バビブベボ', roma: ['ba','bi','bu','be','bo'] },
  { row: 'ぱ', type: 'voiced', hira: 'ぱぴぷぺぽ', kata: 'パピプペポ', roma: ['pa','pi','pu','pe','po'] },
]

const options = ref({ hiragana: true, katakana: false, clear: true, voiced: false, revealAnswer: true })
const phase = ref('setup')
const queue = ref([])
const timeline = ref([])
const total = ref(0)
const mastered = ref(0)
const answer = ref('')
const feedback = ref(null)
const inputEl = ref(null)
const progressEl = ref(null)
const sessionErrors = ref({})
let feedbackTimer
const lifetimeErrors = ref(JSON.parse(localStorage.getItem('kana-errors') || '{}'))
const keyboardRows = [
  ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
  ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
  ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
]

function focusAnswer() {
  if (!window.matchMedia?.('(max-width: 760px)').matches) inputEl.value?.focus()
}

function typeLetter(letter) {
  answer.value += letter
}

function deleteLetter() {
  answer.value = answer.value.slice(0, -1)
}

const kanaRoma = Object.fromEntries(groups.flatMap(group =>
  ['hira', 'kata'].flatMap(script =>
    [...group[script]].map((kana, i) => [kana, group.roma[i].replaceAll('|', '/')])
  )
))

const selectedCount = computed(() => buildPool().length)
const current = computed(() => queue.value[0])
const progress = computed(() => total.value ? Math.round(mastered.value / total.value * 100) : 0)
const progressItems = computed(() => timeline.value)
const topErrors = computed(() => Object.entries(lifetimeErrors.value)
  .sort((a, b) => b[1] - a[1]).slice(0, 6)
  .map(([kana, count]) => ({ kana, count, roma: kanaRoma[kana] || '' })))
const sessionTop = computed(() => Object.entries(sessionErrors.value)
  .sort((a, b) => b[1] - a[1]).map(([kana, count]) => ({ kana, count })))

function buildPool() {
  const scripts = []
  if (options.value.hiragana) scripts.push('hira')
  if (options.value.katakana) scripts.push('kata')
  const types = []
  if (options.value.clear) types.push('clear')
  if (options.value.voiced) types.push('voiced')
  return groups.filter(g => types.includes(g.type)).flatMap(g => scripts.flatMap(script =>
    [...g[script]].map((kana, i) => ({ kana, answers: g.roma[i].split('|'), row: g.row, script }))
  ))
}

function shuffle(items) {
  const result = [...items]
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[result[i], result[j]] = [result[j], result[i]]
  }
  return result
}

function start() {
  const pool = buildPool()
  if (!pool.length) return
  queue.value = shuffle(pool).map((item, index) => ({ ...item, id: `${item.script}-${item.kana}-${index}`, status: 'pending', attempts: 0 }))
  timeline.value = [...queue.value]
  total.value = pool.length
  mastered.value = 0
  sessionErrors.value = {}
  answer.value = ''
  feedback.value = null
  phase.value = 'quiz'
  nextTick(focusAnswer)
}

function submit() {
  if (!answer.value.trim()) return
  const typed = answer.value.trim().toLowerCase()
  answer.value = ''
  if (current.value.answers.includes(typed)) {
    feedback.value = { ok: true, text: '正解！' }
    const item = queue.value.shift()
    item.status = 'correct'
    mastered.value++
  } else {
    const item = queue.value.shift()
    const maxOffset = Math.min(7, queue.value.length)
    const offset = maxOffset ? Math.floor(Math.random() * maxOffset) + 1 : 0
    item.status = 'wrong'
    const retryItem = { ...item, id: `${item.id}-retry-${item.attempts + 1}`, status: 'pending', attempts: item.attempts + 1 }
    queue.value.splice(offset, 0, retryItem)
    const itemAfterRetry = queue.value[offset + 1]
    const timelineIndex = itemAfterRetry ? timeline.value.findIndex(entry => entry.id === itemAfterRetry.id) : -1
    if (timelineIndex >= 0) timeline.value.splice(timelineIndex, 0, retryItem)
    else timeline.value.push(retryItem)
    sessionErrors.value[item.kana] = (sessionErrors.value[item.kana] || 0) + 1
    lifetimeErrors.value[item.kana] = (lifetimeErrors.value[item.kana] || 0) + 1
    localStorage.setItem('kana-errors', JSON.stringify(lifetimeErrors.value))
    feedback.value = {
      ok: false,
      text: options.value.revealAnswer ? `正确答案是 ${item.answers[0]}` : '还不对，再想一想',
    }
  }
  clearTimeout(feedbackTimer)
  feedbackTimer = setTimeout(() => { feedback.value = null }, 700)
  if (!queue.value.length) phase.value = 'done'
  else nextTick(focusAnswer)
}

watch(() => current.value?.id, async () => {
  await nextTick()
  const container = progressEl.value
  const active = container?.querySelector('.current')
  if (!container || !active) return
  container.scrollTo({
    left: Math.max(0, active.offsetLeft - container.clientWidth / 2 + active.clientWidth / 2),
    behavior: 'smooth',
  })
})

function resetStats() {
  lifetimeErrors.value = {}
  localStorage.removeItem('kana-errors')
}
</script>

<template>
  <div class="page-shell" :class="{ 'quiz-phase': phase === 'quiz' }">
    <header class="site-header">
      <button class="brand" @click="phase = 'setup'" aria-label="返回首页">
        <span class="brand-mark">あ</span><span>かな帖</span>
      </button>
      <span class="header-note">每日一点，记住每一个音</span>
    </header>

    <main>
      <section v-if="phase === 'setup'" class="setup-grid">
        <div class="intro">
          <p class="eyebrow">KANA PRACTICE</p>
          <h1>把五十音，<br><em>写进记忆里。</em></h1>
          <p class="lead">选择范围，输入罗马音。答错的假名会回到队伍后面，直到全部答对。</p>
          <div class="ink-line"><span></span><i>いっしょに頑張ろう</i></div>
        </div>

        <div class="paper-card setup-card">
          <div class="card-heading"><span>01</span><div><small>练习设置</small><h2>今天想练什么？</h2></div></div>
          <div class="setting-block">
            <label>文字类型</label>
            <div class="choice-row">
              <button :class="{ active: options.hiragana }" @click="options.hiragana = !options.hiragana"><b>あ</b><span>平假名</span><i></i></button>
              <button :class="{ active: options.katakana }" @click="options.katakana = !options.katakana"><b>ア</b><span>片假名</span><i></i></button>
            </div>
          </div>
          <div class="setting-block">
            <label>音节范围</label>
            <div class="choice-row compact">
              <button :class="{ active: options.clear }" @click="options.clear = !options.clear"><span>清音</span><small>か · さ · た</small><i></i></button>
              <button :class="{ active: options.voiced }" @click="options.voiced = !options.voiced"><span>浊音・半浊音</span><small>が · ざ · ぱ</small><i></i></button>
            </div>
          </div>
          <div class="setting-block behavior-setting">
            <div>
              <label for="reveal-answer">答错时显示答案</label>
              <small>{{ options.revealAnswer ? '立即显示正确罗马音' : '只提示错误，稍后再试' }}</small>
            </div>
            <button id="reveal-answer" class="switch" role="switch" :aria-checked="options.revealAnswer" :class="{ on: options.revealAnswer }" @click="options.revealAnswer = !options.revealAnswer"><i></i></button>
          </div>
          <button class="primary" :disabled="!selectedCount" @click="start">开始练习 <span>{{ selectedCount }} 字</span><b>→</b></button>
          <p v-if="!selectedCount" class="warning">请至少选择一种文字类型和音节范围</p>
        </div>

        <aside class="stats-card">
          <div class="stats-title"><span>错误手帖</span><button v-if="topErrors.length" @click="resetStats">清空</button></div>
          <p v-if="!topErrors.length" class="empty">这里会记下经常答错的假名。<br>现在还是干干净净的一页。</p>
          <div v-else class="error-list">
            <div v-for="(item, index) in topErrors" :key="item.kana" class="error-row">
              <span class="rank">0{{ index + 1 }}</span>
              <span class="error-kana"><b>{{ item.kana }}</b><small>{{ item.roma }}</small></span>
              <div class="error-bar"><i :style="{ width: Math.max(12, item.count / topErrors[0].count * 100) + '%' }"></i></div>
              <span>{{ item.count }} 次</span>
            </div>
          </div>
        </aside>
      </section>

      <section v-else-if="phase === 'quiz'" class="quiz-wrap">
        <div class="quiz-top">
          <button class="text-button" @click="phase = 'setup'">← 结束练习</button>
          <div class="progress-copy"><span>{{ mastered }} / {{ total }}</span><small>已掌握</small></div>
        </div>
        <div ref="progressEl" class="kana-progress" aria-label="练习进度">
          <span v-for="item in progressItems" :key="item.id" :class="[item.status, { current: item.id === current?.id }]">{{ item.kana }}</span>
        </div>
        <div class="paper-card quiz-card">
          <span class="quiz-label">这个假名怎么读？</span>
          <div class="kana">{{ current?.kana }}</div>
          <form @submit.prevent="submit">
            <input ref="inputEl" v-model="answer" autocomplete="off" autocapitalize="none" spellcheck="false" placeholder="输入罗马音" aria-label="输入罗马音">
            <div class="mobile-answer" role="textbox" aria-label="已输入的罗马音" aria-readonly="true">
              <span v-if="answer">{{ answer }}</span><span v-else class="placeholder">输入罗马音</span>
            </div>
            <button type="submit" :disabled="!answer.trim()">确认</button>
          </form>
          <div class="feedback" :class="[{ show: feedback }, feedback?.ok ? 'correct' : 'wrong']"><b>{{ feedback?.text }}</b><span v-if="feedback && !feedback.ok">已移到后面，稍后再试</span></div>
        </div>
        <div class="virtual-keyboard" aria-label="罗马音虚拟键盘">
          <div v-for="(row, index) in keyboardRows" :key="index" class="keyboard-row">
            <button v-for="letter in row" :key="letter" type="button" @click="typeLetter(letter)">{{ letter }}</button>
            <button v-if="index === 2" type="button" class="delete-key" aria-label="删除" @click="deleteLetter">删除</button>
          </div>
          <button type="button" class="submit-key" :disabled="!answer.trim()" @click="submit">确认</button>
        </div>
        <p class="key-hint"><kbd>Enter</kbd> 提交答案</p>
      </section>

      <section v-else class="done-wrap">
        <div class="stamp">完</div>
        <p class="eyebrow">SESSION COMPLETE</p>
        <h1>今日练习，完成。</h1>
        <p>你已经正确认出了全部 <b>{{ total }}</b> 个假名。</p>
        <div class="paper-card result-card">
          <div><strong>{{ total }}</strong><span>掌握字数</span></div>
          <div><strong>{{ Object.values(sessionErrors).reduce((a,b) => a+b, 0) }}</strong><span>本轮错误</span></div>
          <div><strong>{{ sessionTop[0]?.kana || '—' }}</strong><span>重点复习</span></div>
        </div>
        <div class="done-actions"><button class="primary" @click="start">再练一次 <b>→</b></button><button class="secondary" @click="phase = 'setup'">调整范围</button></div>
      </section>
    </main>
    <footer><span>かな帖 · KANA NOTE</span><i></i><span>坚持，是记忆最好的墨水。</span></footer>
  </div>
</template>
