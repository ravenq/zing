export interface RssItem {
  title: string;
  author: string;
  enclosureUrl: string;
  durationText: string;
  imageUrl: string;
  guid: string;
}

function decodeEntities(text: string): string {
  return text.split('&lt;').join('<')
    .split('&gt;').join('>')
    .split('&quot;').join('"')
    .split('&#39;').join("'")
    .split('&apos;').join("'")
    .split('&amp;').join('&');
}

function stripCData(text: string): string {
  const start: number = text.indexOf('<![CDATA[');
  if (start < 0) {
    return text.trim();
  }
  const end: number = text.indexOf(']]>', start);
  if (end < 0) {
    return text.substring(start + 9).trim();
  }
  return text.substring(start + 9, end).trim();
}

function cleanText(text: string): string {
  return decodeEntities(stripCData(text));
}

function extractTag(block: string, tagName: string): string {
  const open: string = '<' + tagName;
  const start: number = block.indexOf(open);
  if (start < 0) {
    return '';
  }
  const afterOpen: number = block.indexOf('>', start);
  if (afterOpen < 0) {
    return '';
  }
  const close: string = '</' + tagName + '>';
  const end: number = block.indexOf(close, afterOpen);
  if (end < 0) {
    return '';
  }
  return cleanText(block.substring(afterOpen + 1, end));
}

function extractNamespaced(block: string, localName: string): string {
  const open: string = '<';
  let cursor: number = 0;
  while (cursor < block.length) {
    const lt: number = block.indexOf(open, cursor);
    if (lt < 0) {
      return '';
    }
    const gt: number = block.indexOf('>', lt);
    if (gt < 0) {
      return '';
    }
    const head: string = block.substring(lt + 1, gt);
    if (head.charAt(head.length - 1) === '/') {
      cursor = gt + 1;
      continue;
    }
    const colon: number = head.indexOf(':');
    let tagLocal: string = head;
    if (colon >= 0) {
      tagLocal = head.substring(colon + 1);
    }
    const space: number = tagLocal.indexOf(' ');
    if (space >= 0) {
      tagLocal = tagLocal.substring(0, space);
    }
    cursor = gt + 1;
    if (tagLocal !== localName) {
      continue;
    }
    const close: string = '</';
    const closeStart: number = block.indexOf(close, gt);
    if (closeStart < 0) {
      return '';
    }
    const closeGt: number = block.indexOf('>', closeStart);
    if (closeGt < 0) {
      return '';
    }
    return cleanText(block.substring(gt + 1, closeStart));
  }
  return '';
}

function extractAttribute(block: string, tagName: string, attrName: string): string {
  const open: string = '<' + tagName;
  const cursor: number = block.indexOf(open);
  if (cursor < 0) {
    return '';
  }
  const tagEnd: number = block.indexOf('>', cursor);
  if (tagEnd < 0) {
    return '';
  }
  const tagHead: string = block.substring(cursor, tagEnd);
  return readAttribute(tagHead, attrName);
}

function readAttribute(tagHead: string, attrName: string): string {
  const patterns: string[] = [attrName + '="', attrName + "='"];
  for (let p = 0; p < patterns.length; p++) {
    const key: string = patterns[p];
    const pos: number = tagHead.indexOf(key);
    if (pos >= 0) {
      const valueStart: number = pos + key.length;
      const quote: string = key.charAt(key.length - 1);
      const valueEnd: number = tagHead.indexOf(quote, valueStart);
      if (valueEnd >= 0) {
        return decodeEntities(tagHead.substring(valueStart, valueEnd));
      }
    }
  }
  return '';
}

function extractImageUrl(block: string): string {
  const tag: string = ':image';
  let cursor: number = block.indexOf(tag);
  while (cursor >= 0) {
    const tagEnd: number = block.indexOf('>', cursor);
    if (tagEnd >= 0) {
      const head: string = block.substring(block.lastIndexOf('<', cursor), tagEnd);
      const href: string = readAttribute(head, 'href');
      if (href.length > 0) {
        return href;
      }
    }
    cursor = block.indexOf(tag, cursor + tag.length);
  }
  return extractTag(block, 'image');
}

function splitItems(xml: string): string[] {
  const items: string[] = [];
  const openTag: string = '<item';
  const closeTag: string = '</item>';
  let cursor: number = xml.indexOf(openTag);
  while (cursor >= 0) {
    const end: number = xml.indexOf(closeTag, cursor);
    if (end < 0) {
      break;
    }
    items.push(xml.substring(cursor, end + closeTag.length));
    cursor = xml.indexOf(openTag, end);
  }
  return items;
}

export function parseRss(xml: string): RssItem[] {
  const blocks: string[] = splitItems(xml);
  const result: RssItem[] = [];
  for (let i = 0; i < blocks.length; i++) {
    const block: string = blocks[i];
    let duration: string = extractNamespaced(block, 'duration');
    if (duration.length === 0) {
      duration = extractTag(block, 'duration');
    }
    let image: string = extractImageUrl(block);
    if (image.length === 0) {
      image = extractNamespaced(block, 'image');
    }
    let author: string = extractNamespaced(block, 'author');
    if (author.length === 0) {
      author = extractTag(block, 'author');
    }
    result.push({
      title: extractTag(block, 'title'),
      author: author,
      enclosureUrl: extractAttribute(block, 'enclosure', 'url'),
      durationText: duration,
      imageUrl: image,
      guid: extractTag(block, 'guid')
    });
  }
  return result;
}
