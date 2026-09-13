# Rewrap Markdown Demo: Unwrapped Source

This file is the unwrapped counterpart to `gfm_supported_wrapped.md`,
before running the Rewrap Markdown text filter in BBEdit. The prose is
deliberately a little ridiculous because useful wrapping demos need
paragraphs that run too long, contain
`inline code spans that should stay together`, preserve
[links with descriptive text that should remain atomic](https://github.com/sethdill/rewrap_markdown/blob/main/Samples/gfm_supported_unwrapped.py),
and avoid breaking a bare URL such as
https://github.com/sethdill/rewrap_markdown/issues/new even when that
URL is longer than the target width.

The tool is most interesting when Markdown context changes how
continuation lines should be indented, so this document includes list
items, quoted list items, task list items, footnotes, alert blocks,
tables, fenced code blocks, HTML, hard line breaks, autolinks, images,
comments, escaped punctuation, and small GitHub-flavored extras like
:sparkles:, @octocat, #123, GH-456, and sethdill/rewrap_markdown@main.

Setext Heading That Should Stay Verbatim Even Though This Line Is Too Long To Be Pretty
=====================================================================================

## Styling Text While The Sentence Keeps Going Far Past A Comfortable Column

Plain emphasis such as *italic text*, **bold text**, ***bold italic
text***, ~~struck through text~~, <sub> subscript text </sub>, and
<sup> superscript text </sup> should survive reflow, as should color
swatches written as inline code like `#0969DA`, `rgb(9, 105, 218)`,
and `hsl(212, 92%, 45%)`.

## Links, Images, Anchors, And Things That Look Like Links

Here is an inline link to [the repository README](../README.md), a
reference-style link to [a mysterious index][mystery-index], an image
with a deliberately long alt text
![a small imaginary badge that says markdown rewrapped with surprising politeness](https://dummyimage.com/160x40/0969da/ffffff.png&text=Rewrap+Markdown),
an autolink <https://github.github.com/gfm/>, an email autolink
<nobody@example.com>, and a relative link to
[the Swift source](../Sources/RewrapMarkdownCore/RewrapMarkdown.swift)
that should not be split internally.

<a id="custom-anchor-for-the-demo"></a>

Jump back to [the custom anchor](#custom-anchor-for-the-demo) after
you have wandered through the rest of this intentionally lopsided
document.

[mystery-index]: https://example.com/a/reference/link/that/should/remain/together "Reference links are useful demo bait"

## Lists And Nested Lists

- This unordered list item is extravagantly long because the wrapped
  continuation lines should align underneath the text of the bullet
  rather than underneath the marker, and it includes
  [a link item with enough text to make wrapping decisions visible](https://example.com/list/item/with/a/long/path)
  plus `inline code that should remain intact`.
- This second unordered list item contains a nested list so the
  rewrapper has to preserve indentation while still making readable
  lines from an aggressively unwrapped source sentence.
   - This nested bullet continues for an unreasonable distance and
     includes a bare URL
     https://example.com/nested/list/item/with/a/bare/url/that/should/not/be/split
     and some ordinary words after it.
   - [ ] This nested task list item is unchecked and long enough to
     show how GitHub task markers behave when treated like ordinary
     list text by the wrapper.
   - [x] This nested task list item is checked and contains an escaped
     parenthesis marker \(Optional) so GitHub does not get too clever
     at the front of the item.
- This final unordered item uses a hard line break at the end of this
  source line so the next sentence must not be merged into it.  
  This continuation after a hard break should still be wrapped
  independently while preserving the logical break.

1. This ordered list item is too long on purpose and should preserve
   the original number and punctuation while wrapping continuation
   lines under the item text instead of under the number.
2. This ordered list item contains a nested ordered list with enough
   words to make indentation visible in the rewrapped output.
   1. The nested ordered item has a long sentence with `code`,
      [a nested link](https://example.com/ordered/nested/link), and
      extra words after the link so the result is easy to compare.
   2. The second nested ordered item is less interesting but still far
      too long for any humane markdown document.

## Quoted Material

> A plain blockquote can run for a very long time, perhaps while
> explaining that the rewrapper strips one quote level, wraps the
> interior, and reapplies the quote marker to every line so the result
> still looks like a blockquote instead of a confused paragraph.
>
> - This quoted bullet item is the star of the demo because
>   continuation lines should carry both the quote marker and the list
>   continuation indentation, even when the sentence includes
>   [a quoted list link that should remain unsplit](https://example.com/quoted/list/link/with/too/many/segments).
> - [ ] This quoted task item should behave like quoted list prose and
>   continue to line up under the text after the task marker, which is
>   exactly the sort of tiny detail that makes a hand-rolled Markdown
>   wrapper feel thoughtful.
>
> 1. This quoted ordered list item should also retain its quote prefix
>    and ordered-list hanging indentation after wrapping.
> 2. This quoted ordered list item includes `inline code`,
>    <https://example.com/quoted/autolink>, and enough ordinary text
>    to force multiple wrapped lines.

> [!NOTE]
> GitHub alerts are blockquotes with a special marker, so this note
> should keep its alert syntax while its long explanatory sentence is
> reflowed inside the quoted block.

> [!TIP]
> A tip can include a list when hand-written Markdown drifts in that
> direction, and this sentence is intentionally long so the result
> demonstrates whether the quote marker remains stable.

> [!IMPORTANT]
> Important information needs to stay visually important after
> wrapping, even when the actual prose is just filler about imaginary
> release notes and highly specific formatting preferences.

> [!WARNING]
> Warning text should remain quoted and should not accidentally merge
> with neighboring alert blocks when blank quoted separator lines are
> present.

> [!CAUTION]
> Caution text rounds out the alert set and gives the rewrapper one
> more blockquote-shaped structure to preserve.

## Code

Inline code such as `swift build -c release`,
``code with ` nested tick text``, and `let width = 70` should be
treated as atomic text while surrounding prose wraps normally.

```swift
// This fenced Swift block is intentionally long and should pass through unchanged by the rewrapper even though the line below is far beyond the normal target width.
let message = "Fenced code blocks should not be rewrapped, because code has its own indentation, punctuation, comments, strings, and alignment that a prose wrapper should leave alone."
print(message)
```

~~~python
def also_leave_tilde_fences_alone():
    return "Tilde fences are supported too, and the content inside this fence should remain exactly as it was written."
~~~

    This indented code block is part of classic Markdown and should remain visibly code-like, although this particular rewrapper is primarily tuned around fenced code blocks.

## Tables

| Feature | Why It Matters | Expected Treatment |
|:---|:---:|---:|
| Tables | Tables depend on line structure and separators, so wrapping individual cells would corrupt the source layout. | Pass through |
| Inline links | Links like [this table link](https://example.com/table/link/that/is/long) should remain textually intact. | Atomic |
| Code spans | Values such as `MD_REWRAP_WIDTH=80` should not split across lines. | Atomic |

## HTML Blocks And Comments

<details>
<summary>This summary line is intentionally long and should remain inside an HTML block without being rewrapped by the Markdown prose logic.</summary>
<p>This paragraph is raw HTML inside the details element, and for this demo it should pass through unchanged even though it is extremely long and would otherwise be a perfect candidate for wrapping.</p>
</details>

<!-- This hidden HTML comment is intentionally long and should be preserved as source text rather than interpreted as a paragraph to reflow, because comments are a Markdown-adjacent escape hatch. -->

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://dummyimage.com/640x320/0d1117/ffffff.png&text=Dark+Mode">
  <img alt="A placeholder image in a picture element" src="https://dummyimage.com/640x320/ffffff/0969da.png&text=Light+Mode">
</picture>

## Escapes, Rules, And Manual Breaks

Escaped Markdown punctuation like \*literal asterisks\*, \_literal
underscores\_, \ [literal brackets\], and \# literal hash marks should
remain readable while the surrounding sentence is wrapped like
ordinary prose.

This line ends with a backslash hard break, so the following source
line should not be merged into it even though both lines belong to a
single visual thought.\
This is the line after the backslash hard break, and it has enough
extra words to require wrapping on its own after the forced break is
preserved.

This line ends with two spaces for a Markdown hard break, which is
easy to lose if the wrapper trims too aggressively.  
This is the line after the two-space hard break, and it also keeps
talking far too long because the demo needs visible behavior rather
than tasteful writing.

---

## Footnotes

Here is a simple footnote reference [^simple], and here is another
reference [^long-note] attached to an absurdly long sentence that
should wrap normally while the footnote definitions later behave like
hanging-indented list items.

[^simple]: This is a short footnote definition that is still long enough to wrap and show the marker-preserving behavior of the filter.
[^long-note]: This footnote definition is much longer and includes [a footnote link](https://example.com/footnote/link/that/should/remain/whole), `footnote code`, and enough filler words to require multiple continuation lines under the footnote marker.

    This indented continuation belongs to the long footnote in many Markdown renderers and is here to see how gracefully the demo behaves around more complex footnote bodies.

## Final Paragraph

The closing paragraph mentions every supported demo case one more
time: headings, paragraphs, links, images, autolinks, lists, task
lists, blockquotes, quoted lists, alerts, code spans, fenced code,
tables, HTML, comments, hard breaks, thematic breaks, escaped
punctuation, GitHub references, emoji codes, and footnotes all appear
in this intentionally unwrapped Markdown file.
