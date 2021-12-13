# XML 工具模块

用来解析 XML 文档的简单工具

通过 `require('app/xml')` 来调用

## newParser

> local parser = xml.newParser()

创建一个新的 XML 解析器

- parser `{XmlParser}` 返回创建的解析器

## 类 XmlParser

### toXmlString

> parser.toXmlString(value)

编码 XML 字符串，将字符串中的特殊符号转码成 XML 可以接受的格式

- value `{string}` 要编码的字符串

### fromXmlString

> parser.fromXmlString(value)

解析 XML 字符串，将编码过的字符串还原成原始的格式

- value `{string}` 要解析的字符串

### parseArgs

> parser.parseArgs(node, s)

解析 XML 节点属性

- node `{XmlNode}` 要解析的节点
- s `{string}` 要解析的字符串

### parseXmlText

> local topNode = parser.parseXmlText(xmlText)

解析 XML 文档

- xmlText `{string}` 要解析的 XML 文档

## 类 XmlNode

### value

> local value = node.value()

返回 XML 节点的值

### setValue

> node.setValue(value)

设置 XML 节点的值

- value `{string}` 节点值

### name

> local name = node.name()

返回 XML 节点的名称

### setName

> node.setName(name)

设置 XML 节点的名称

- name `{string}` 节点名称

### children

> local children = node.children()

返回 XML 节点的所有子节点

### numChildren

> local count = node.numChildren()

返回 XML 节点的子节点数量

### addChild

> node.addChild(childNode)

添加一个子节点

### properties

> local properties = node.properties()

返回 XML 节点的所有属性

### numProperties

> local count = node.numProperties()

返回XML 节点的属性的数量

### addProperty

> node.addProperty(name, value)

添加一个新的属性

- name `{string}` 属性名
- value `{string}` 属性值