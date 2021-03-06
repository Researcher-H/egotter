class Heart {
  constructor(id, offsetX, offsetY, width, height, imageWidth, users) {
    this.id = id;
    this._ = offsetX;
    this.offsetY = offsetY;
    this.width = width;
    this.height = height;
    this.imageWidth = imageWidth;
    this.count = 0;
    this.users = users;
    this.elem = d3.select('#' + id);
  }

  draw() {
    this.drawWatermark();
    this.drawFirstPrize();
    this.drawSecondPrize();
    this.drawThirdPrize();

    this.drawRect(1, 0, {left: 1, top: 1});
    this.drawRect(2, 0, {top: 1});
    this.drawRect(3, 0, {top: 1, right: 1});
    this.drawRect(7, 0, {left: 1, top: 1});
    this.drawRect(8, 0, {top: 1});
    this.drawRect(9, 0, {top: 1, right: 1});

    this.drawRect(0, 1, {left: 1, top: 1});
    this.drawRect(1, 1);
    this.drawRect(2, 1);
    this.drawRect(3, 1);
    this.drawRect(4, 1, {top: 1, right: 1});
    this.drawRect(6, 1, {left: 1, top: 1});
    this.drawRect(7, 1);
    this.drawRect(8, 1);
    this.drawRect(9, 1);
    this.drawRect(10, 1, {top: 1, right: 1});

    this.drawRect(0, 2, {left: 1});
    this.drawRect(1, 2);
    this.drawRect(2, 2);
    this.drawRect(3, 2);
    this.drawRect(4, 2);
    this.drawRect(5, 2, {top: 1});
    this.drawRect(6, 2);
    this.drawRect(7, 2);
    this.drawRect(8, 2);
    this.drawRect(9, 2);
    this.drawRect(10, 2, {right: 1});

    this.drawRect(0, 3, {left: 1, bottom: 1});
    this.drawRect(1, 3);
    this.drawRect(2, 3);
    this.drawRect(3, 3);
    this.drawRect(4, 3);
    this.drawRect(5, 3);
    this.drawRect(6, 3);
    this.drawRect(7, 3);
    this.drawRect(8, 3);
    this.drawRect(9, 3);
    this.drawRect(10, 3, {right: 1, bottom: 1});

    this.drawRect(1, 4, {left: 1, bottom: 1});
    this.drawRect(2, 4);
    this.drawRect(3, 4);
    this.drawRect(4, 4);
    this.drawRect(5, 4);
    this.drawRect(6, 4);
    this.drawRect(7, 4);
    this.drawRect(8, 4);
    this.drawRect(9, 4, {right: 1, bottom: 1});

    this.drawRect(2, 5, {left: 1, bottom: 1});
    this.drawRect(3, 5);
    this.drawRect(4, 5);
    this.drawRect(5, 5);
    this.drawRect(6, 5);
    this.drawRect(7, 5);
    this.drawRect(8, 5, {right: 1, bottom: 1});

    this.drawRect(3, 6, {left: 1, bottom: 1});
    this.drawRect(4, 6);
    this.drawRect(5, 6);
    this.drawRect(6, 6);
    this.drawRect(7, 6, {right: 1, bottom: 1});

    this.drawRect(4, 7, {left: 1, bottom: 1});
    this.drawRect(5, 7);
    this.drawRect(6, 7, {right: 1, bottom: 1});

    this.drawRect(5, 8, {right: 1, bottom: 1, left: 1});
  }

  drawRect(x, y, border) {
    var p = this.findPosition(x, y);
    var index = this.count + 3;

    if (this.users[index] && this.users[index]['profile_image_url']) {
      var user = this.users[index];
      this.elem.append("svg:image")
          .attr("x", p.x)
          .attr("y", p.y)
          .attr("width", p.width)
          .attr("height", p.width)
          .attr("onclick", 'window.open("' + this.timelinePath(user.screen_name) + '")')
          .attr("xlink:href", user['profile_image_url']);
    } else {
      this.elem.append("svg:rect")
          .attr("x", p.x)
          .attr("y", p.y)
          .attr("width", p.width)
          .attr("height", p.width)
          .attr("rx", 0)
          .attr("ry", 0)
          .attr("fill", '#EA2184');
    }

    if (border) {
      if (border['top']) {
        this.drawLine(p.x, p.y, p.x + p.width, p.y);
      }
      if (border['right']) {
        this.drawLine(p.x + p.width, p.y, p.x + p.width, p.y + p.width);
      }
      if (border['bottom']) {
        this.drawLine(p.x, p.y + p.width, p.x + p.width, p.y + p.width);
      }
      if (border['left']) {
        this.drawLine(p.x, p.y, p.x, p.y + p.width);
      }
    }

    this.count++;
  }

  findPosition(x, y) {
    var width = this.imageWidth;
    x = width * x + (this.width - width * 11) / 2;
    y = width * y + (this.height - width * 9) / 2 + this.offsetY;
    return {x: x, y: y, width: width};
  }

  drawLine(x1, y1, x2, y2) {
    this.elem.append("svg:line")
        .attr("x1", x1)
        .attr("y1", y1)
        .attr("x2", x2)
        .attr("y2", y2)
        .attr("stroke", '#EA2184');
  }

  drawPrize(id, index) {
    var rect = $('#' + id);
    var user = this.users[index];
    if (!user) {
      return;
    }

    this.elem.append("svg:image")
        .attr("x", rect.attr('x'))
        .attr("y", rect.attr('y'))
        .attr("width", rect.attr('width'))
        .attr("height", rect.attr('height'))
        .attr("onclick", 'window.open("' + this.timelinePath(user.screen_name) + '")')
        .attr("xlink:href", user['profile_image_url']);

    var x = parseInt(rect.attr('x')) + parseInt(rect.attr('width')) / 2;
    var y = parseInt(rect.attr('y')) + parseInt(rect.attr('height')) + 15;
    this.elem.append("svg:text")
        .attr("x", x)
        .attr("y", y)
        .attr("dominant-baseline", 'middle')
        .attr("text-anchor", 'middle')
        .attr("onclick", 'window.open("' + this.timelinePath(user.screen_name) + '")')
        .text('@' + user.screen_name);
  }

  drawFirstPrize() {
    this.drawPrize('close-friends-first-prize', 0);
  }

  drawSecondPrize() {
    this.drawPrize('close-friends-second-prize', 1);
  }

  drawThirdPrize() {
    this.drawPrize('close-friends-third-prize', 2);
  }

  drawWatermark() {
    var p1 = this.findPosition(10, 3);
    var p2 = this.findPosition(5, 8);
    new Watermark(this.id, p1.x + p1.width, p2.y + p2.width).draw();
  }

  timelinePath(screenName) {
    // timeline_path
    return '/timelines/' + screenName + '?via=heart';
  }
}

window.Heart = Heart;

class Watermark {
  constructor(id, x, y) {
    this.elem = d3.select('#' + id);
    this.x = x;
    this.y = y;
    this.name = '#仲良しランキング';
    this.domain = 'egotter.com';
    this.nameOffset = 14;
  }

  draw() {
    this.drawName();
    this.drawDomain();
  }

  drawName() {
    this.elem.append("svg:text")
        .attr("x", this.x)
        .attr("y", this.y - this.nameOffset)
        .attr("text-anchor", 'end')
        .attr("font-size", 10)
        .attr("style", 'fill: #EA2184;')
        .text(this.name);
  }

  drawDomain() {
    this.elem.append("svg:text")
        .attr("x", this.x)
        .attr("y", this.y)
        .attr("text-anchor", 'end')
        .attr("font-size", 12)
        .attr("style", 'fill: #EA2184;')
        .text(this.domain);
  }
}
