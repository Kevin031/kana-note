import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import App from './App.vue'

describe('五十音练习', () => {
  beforeEach(() => {
    localStorage.clear()
    Element.prototype.scrollTo = vi.fn()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  async function enterQuiz(wrapper) {
    await wrapper.find('.setup-card .primary').trigger('click')
    expect(wrapper.find('.quiz-card').exists()).toBe(true)
    return wrapper.find('.quiz-card input')
  }

  it('提交错误答案后立即清空输入框并记录错误', async () => {
    const wrapper = mount(App)
    const input = await enterQuiz(wrapper)

    await input.setValue('definitely-wrong')
    await wrapper.find('.quiz-card form').trigger('submit')

    expect(input.element.value).toBe('')
    expect(wrapper.find('.feedback').text()).toContain('正确答案是')
    expect(Object.values(JSON.parse(localStorage.getItem('kana-errors')))).toEqual([1])
  })

  it('关闭答案显示后，错误提示不会泄露正确答案', async () => {
    const wrapper = mount(App)
    await wrapper.find('#reveal-answer').trigger('click')
    const input = await enterQuiz(wrapper)

    await input.setValue('definitely-wrong')
    await wrapper.find('.quiz-card form').trigger('submit')

    expect(input.element.value).toBe('')
    expect(wrapper.find('.feedback').text()).toContain('还不对，再想一想')
    expect(wrapper.find('.feedback').text()).not.toContain('正确答案是')
  })

  it('答错后快速输入下一题答案并回车时仍会正常校验', async () => {
    vi.spyOn(Math, 'random').mockReturnValue(0)
    const wrapper = mount(App)
    const input = await enterQuiz(wrapper)

    expect(wrapper.find('.kana').text()).toBe('い')
    await input.setValue('wrong')
    await wrapper.find('.quiz-card form').trigger('submit')
    expect(wrapper.find('.kana').text()).toBe('う')
    const progressAfterWrong = wrapper.findAll('.kana-progress span')
    expect(progressAfterWrong[0].text()).toBe('い')
    expect(progressAfterWrong[0].classes()).toContain('wrong')
    expect(progressAfterWrong[1].text()).toBe('う')
    expect(progressAfterWrong[2].text()).toBe('い')
    expect(progressAfterWrong[2].classes()).toContain('pending')

    await input.setValue('u')
    await wrapper.find('.quiz-card form').trigger('submit')

    expect(input.element.value).toBe('')
    expect(wrapper.find('.feedback').text()).toContain('正解')
    expect(wrapper.find('.progress-copy').text()).toContain('1 / 46')
    expect(wrapper.find('.kana').text()).toBe('い')
    expect(wrapper.findAll('.kana-progress span')[1].classes()).toContain('correct')
  })

  it('提交正确答案后无等待地清空输入框、推进进度并切换题目', async () => {
    vi.spyOn(Math, 'random').mockReturnValue(0)
    const wrapper = mount(App)
    const input = await enterQuiz(wrapper)

    await input.setValue('i')
    await wrapper.find('.quiz-card form').trigger('submit')
    expect(input.element.value).toBe('')
    expect(wrapper.find('.feedback').text()).toContain('正解')
    expect(wrapper.find('.progress-copy').text()).toContain('1 / 46')
    expect(wrapper.find('.kana').text()).toBe('う')
    expect(wrapper.find('.kana-progress span').classes()).toContain('correct')
  })

  it('错误手帖在假名旁显示罗马音', async () => {
    localStorage.setItem('kana-errors', JSON.stringify({ し: 3, づ: 2, ア: 1 }))
    const wrapper = mount(App)

    const rows = wrapper.findAll('.error-row')
    expect(rows).toHaveLength(3)
    expect(rows[0].find('b').text()).toBe('し')
    expect(rows[0].find('small').text()).toBe('shi')
    expect(rows[1].find('b').text()).toBe('づ')
    expect(rows[1].find('small').text()).toBe('zu/du')
    expect(rows[2].find('b').text()).toBe('ア')
    expect(rows[2].find('small').text()).toBe('a')
  })

  it('可以使用移动端虚拟键盘输入、删除和提交答案', async () => {
    vi.spyOn(Math, 'random').mockReturnValue(0)
    const wrapper = mount(App)
    await enterQuiz(wrapper)

    const keys = wrapper.findAll('.virtual-keyboard .keyboard-row button')
    await keys.find(key => key.text() === 'i').trigger('click')
    expect(wrapper.find('.mobile-answer').text()).toBe('i')

    await wrapper.find('.delete-key').trigger('click')
    expect(wrapper.find('.mobile-answer').text()).toBe('输入罗马音')

    await keys.find(key => key.text() === 'i').trigger('click')
    await wrapper.find('.submit-key').trigger('click')
    expect(wrapper.find('.progress-copy').text()).toContain('1 / 46')
  })
})
