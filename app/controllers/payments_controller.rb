class PaymentsController < ApplicationController
  before_action :response, only: [:new, :penalty_check, :pay]
  before_action :individual_required, only: [:new]
  skip_before_action :verify_authenticity_token, only: [:pay]
  def new
    @title = "Pay Fine"
    if @fine.payment_status
      redirect_to fines_path
    else
      @payment = Payment.new
    end
  end

  def payment_params
    params.require(:payment).permit(:credit_card_number, :expiration_date, :card_verification_number)
  end

  def fine
    @fine = Fine.find(params[:id])
  end

  def penalty_check
    @penalty_fee = 0.00
    @days_count = (Time.now.to_date - @fine.issue_time.to_date).to_i
    if @days_count <= 5
      @fine.update_attribute(:amount, @fine.amount / 2)
      @fine.penalty_amount = @penalty_fee
      @fine.update_attribute(:payment_status, true)
    else
      @accumulated_payment = calculate_interest(2, @fine.amount, @days_count)
      @penalty_fee = @accumulated_payment - @fine.amount
      @fine.update_attribute(:penalty_amount, @penalty_fee)
      @fine.update_attribute(:payment_status, true)
      @payment.update_attribute(:amount, @accumulated_payment)
    end
  end

  def calculate_interest(interest, amount, days)
    amount * (1.0 + (interest / 100.00)) ** days
  end

  def pay
    if logged_in?
      @current_user = current_user
      @current_user_role = @current_user.role
    else
      @current_user = nil
      @current_user_role = nil
    end
    respond_to do |format|
      if @fine.payment_status
        format.html {
          if @current_user_role == "Individual"
            flash[:error] = "Fine has been paid already!"
            redirect_to fines_path
          else
            redirect_to root_path
          end
        }
        format.json {
          render json: { error: "Fine has been paid already!" }
        }
      else
        @payment = Payment.new(payment_params)
        @payment.fine = @fine
        if @payment.valid?
          penalty_check
          @payment.save
          format.html {
            if @current_user_role == "Individual"
              flash[:notice] = "Payment added successfully!"
              redirect_to fines_path
            else
              redirect_to root_path
            end
          }
          format.json {
            render json: { success: "Payment added successfully!" }
          }
        else
          format.html {
            if @current_user_role == "Individual"
              flash[:error] = "Payment could not be added!"
              render :new
            else
              redirect_to root_path
            end
          }
          format.json {
            render json: { error: "Validation failed for payment", messages: @payment.errors.full_messages }
          }
        end
      end
    end
  end
end
