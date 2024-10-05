resource "aws_lb" "mlflow" {
  idle_timeout       = 60
  internal           = false
  ip_address_type    = "ipv4"
  load_balancer_type = "application"
  name               = "mlflow"
  security_groups = [
    aws_security_group.lb_sg.id,
  ]
  subnets = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id,
  ]
  tags = local.tags
}


resource "aws_lb_target_group" "mlflow" {
  name            = "mlflow"
  port            = 80
  ip_address_type = "ipv4"
  protocol        = "HTTP"
  target_type     = "ip"
  vpc_id          = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    interval            = 30
    matcher             = "401"
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}


resource "aws_alb_listener" "mlflow" {
  load_balancer_arn = aws_lb.mlflow.id
  port              = 80
  protocol          = "HTTP"

  depends_on = [aws_lb.mlflow, aws_lb_target_group.mlflow]

  default_action {
    order            = 1
    target_group_arn = aws_lb_target_group.mlflow.id
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "mlflow" {
  listener_arn = aws_alb_listener.mlflow.id
  priority     = 1
  condition {
    source_ip {
      values = [var.internet_cidr]
    }
  }
  action {
    target_group_arn = aws_lb_target_group.mlflow.id
    type             = "forward"
  }
}